defmodule BnApis.Reminder do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Reminder
  alias BnApis.Reminder.Status
  alias BnApis.Helpers.Utils
  alias BnApis.Organizations.Broker
  alias BnApis.Accounts.Credential
  alias BnApis.AssignedBrokers

  schema "reminders" do
    field :reminder_date, :integer
    field :status_id, :integer
    field :entity_id, :integer
    field :remarks, :string
    field :entity_type, :string
    field :jid, :string

    belongs_to(:created_by, EmployeeCredential)
    timestamps()
  end

  @required [:status_id, :entity_id, :entity_type, :reminder_date]
  @optional [:remarks, :jid, :created_by_id]

  def changeset(reminders, attrs) do
    reminders
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:created_by_id)
  end

  def create_reminder(
        params = %{
          "entity_id" => entity_id,
          "reminder_date" => reminder_date
        },
        user_id,
        entity_type
      ) do
    changeset =
      changeset(%Reminder{}, %{
        status_id: Status.created().id,
        entity_id: entity_id,
        entity_type: entity_type,
        reminder_date: reminder_date,
        created_by_id: user_id,
        remarks: params["remarks"]
      })

    if changeset.valid? do
      # push notification for reminders in case of ground app
      jid =
        case entity_type do
          "brokers" ->
            {:ok, jid} = enqueue_for_push_notification(entity_id, user_id, reminder_date)
            jid

          "commercial_site_visits" ->
            {:ok, jid} = enqueue_for_site_visit_notification(entity_id, DateTime.from_unix!(reminder_date))
            jid

          _ ->
            nil
        end

      changeset
      |> changeset(%{jid: jid})
      |> Repo.insert()
    else
      changeset
    end
  end

  def create_reminder(_params, _logged_in_user, _employee_id), do: {:error, "Invalid params"}

  defp enqueue_for_push_notification(broker_id, created_by_id, reminder_date) do
    reminder_time_10_mins_ago = reminder_date - 10 * 60
    reminder_time_10_mins_ago = DateTime.from_unix!(reminder_time_10_mins_ago)
    Exq.enqueue_at(Exq, "reminders", reminder_time_10_mins_ago, BnApis.Brokers.ReminderNotificationWorker, [broker_id, created_by_id, reminder_date])
  end

  defp enqueue_for_site_visit_notification(visit_id, reminder_time) do
    Exq.enqueue_at(Exq, "reminders", reminder_time, BnApis.Commercial.CommercialSiteVisitNotification, [visit_id, "REMINDER"])
  end

  defp get_employee_details(nil), do: %{}
  defp get_employee_details(emp_cred = %EmployeeCredential{}), do: Map.take(emp_cred, ~w(id name phone_number)a)

  def update_reminder(params = %{"id" => reminder_id}, employee_id) do
    params = Map.take(params, ["reminder_date", "remarks"])

    with %Reminder{} = reminder <- Repo.get_by(Reminder, id: reminder_id, status_id: Status.created().id),
         true <- is_employee_allowed_to_edit?(reminder.created_by_id, employee_id),
         {:ok, updated_reminder} <- Repo.update(changeset(reminder, params)) do
      update_scheduled_job(params["reminder_date"], updated_reminder)
    else
      nil -> {:error, "No reminder found for the given id"}
      false -> {:error, "Users are allowed to edit their own created reminders"}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def update_scheduled_job(nil, _reminder), do: nil

  def update_scheduled_job(reminder_date, reminder) do
    if reminder_date != reminder.reminder_date do
      # remove old scheduled job from queue
      :ok = Exq.Api.remove_scheduled(Exq.Api, reminder.jid)

      # enqueue updated reminder date in the queue
      jid =
        case reminder.entity_type do
          "brokers" ->
            {:ok, jid} = enqueue_for_push_notification(reminder.entity_id, reminder.created_by_id, reminder_date)
            jid

          "commercial_site_visits" ->
            {:ok, jid} = enqueue_for_site_visit_notification(reminder.entity_id, DateTime.from_unix!(reminder_date))
            jid

          _ ->
            nil
        end

      reminder |> changeset(%{jid: jid}) |> Repo.update()
    else
      {:ok, reminder}
    end
  end

  def complete_reminder(
        _params = %{
          "id" => reminder_id
        },
        employee_id
      ) do
    reminder = Repo.get_by(Reminder, id: reminder_id, status_id: Status.created().id)

    case reminder do
      nil ->
        {:error, "Invalid reminder id"}

      reminder ->
        is_employee_allowed_to_edit = is_employee_allowed_to_edit?(reminder.created_by_id, employee_id)

        if is_employee_allowed_to_edit do
          reminder
          |> changeset(%{status_id: Status.completed().id})
          |> Repo.update()
        else
          {:error, "Users are allowed to edit their own created reminders"}
        end
    end
  end

  def cancel_reminder(
        _params = %{
          "id" => reminder_id
        },
        employee_id
      ) do
    reminder = Repo.get_by(Reminder, id: reminder_id, status_id: Status.created().id)

    case reminder do
      nil ->
        {:error, "Invalid reminder id"}

      reminder ->
        is_employee_allowed_to_edit = is_employee_allowed_to_edit?(reminder.created_by_id, employee_id)

        if not is_nil(reminder) and is_employee_allowed_to_edit do
          changeset =
            reminder
            |> changeset(%{status_id: Status.cancelled().id})
            |> Repo.update()

          # remove the scheduled job from queue
          Exq.Api.remove_scheduled(Exq.Api, reminder.jid)
          changeset
        else
          {:error, "Users are allowed to edit their own created reminders"}
        end
    end
  end

  def is_employee_allowed_to_edit?(created_by_id, user_employee_id) do
    created_by_id == user_employee_id
  end

  def get_broker_reminders_for_employee(employee_id, entity_type, params) do
    query =
      Reminder
      |> where([r], r.created_by_id == ^employee_id and r.entity_type == ^entity_type and r.status_id != ^Status.cancelled().id)

    query =
      if not is_nil(params["date_filter"]) do
        date_filter = Utils.parse_to_integer(params["date_filter"])
        ist_date_time = DateTime.from_unix!(date_filter) |> Timex.to_datetime("Asia/Kolkata")

        start_time = ist_date_time |> Timex.beginning_of_day() |> Timex.to_datetime() |> DateTime.to_unix()
        end_time = ist_date_time |> Timex.end_of_day() |> Timex.to_datetime() |> DateTime.to_unix()

        query |> where([r], fragment("? BETWEEN ? AND ?", r.reminder_date, ^start_time, ^end_time))
      else
        query
      end

    reminders =
      query
      |> Repo.all()
      |> Repo.preload(:created_by)
      |> Enum.map(fn reminder ->
        create_get_broker_reminder_response(reminder)
      end)

    {:ok, reminders}
  end

  def get_reminders_for_entity_id(_params, _entity_type) do
    {:error, "Invalid params"}
  end

  def get_nearest_reminders(entity_id, entity_type, reminder_count \\ 5) do
    current_epoch_time = DateTime.utc_now() |> DateTime.to_unix()

    Reminder
    |> where([r], r.entity_id == ^entity_id and r.entity_type == ^entity_type and r.status_id == ^Status.created().id and r.reminder_date > ^current_epoch_time)
    |> order_by([r], asc: r.reminder_date)
    |> limit(^reminder_count)
    |> Repo.all()
    |> Repo.preload(:created_by)
    |> Enum.map(fn reminder ->
      create_get_reminder_response(reminder)
    end)
  end

  defp create_get_reminder_response(reminder) do
    created_by_info = get_employee_details(reminder.created_by)

    %{
      "id" => reminder.id,
      "status_id" => reminder.status_id,
      "entity_id" => reminder.entity_id,
      "entity_type" => reminder.entity_type,
      "reminder_date" => reminder.reminder_date,
      "remarks" => reminder.remarks,
      "created_by_info" => created_by_info
    }
  end

  defp create_get_broker_reminder_response(reminder) do
    created_by_info = get_employee_details(reminder.created_by)
    broker_details = get_broker_details(reminder.entity_id)

    %{
      "id" => reminder.id,
      "status_id" => reminder.status_id,
      "entity_id" => reminder.entity_id,
      "entity_type" => reminder.entity_type,
      "reminder_date" => reminder.reminder_date,
      "remarks" => reminder.remarks,
      "created_by_info" => created_by_info,
      "broker_details" => broker_details,
      "channel_url" => AssignedBrokers.fetch_channel_url(reminder.entity_id, reminder.created_by_id)
    }
  end

  defp get_broker_details(broker_id) do
    broker = Repo.get_by(Broker, id: broker_id)
    credentials = Credential.get_credential_from_broker_id(broker_id) |> Repo.preload(:organization)

    %{
      "broker_name" => broker.name,
      "broker_organization" => credentials.organization.name,
      "broker_address" => credentials.organization.firm_address,
      "phone_number" => credentials.phone_number,
      "broker_id" => broker_id,
      "uuid" => credentials.uuid
    }
  end
end
