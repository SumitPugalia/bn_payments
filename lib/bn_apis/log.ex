defmodule BnApis.Log do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Organizations.Broker
  alias BnApis.Log

  schema "logs" do
    field :changes, :map
    field :user_id, :integer
    field :user_type, :string
    field :entity_id, :integer
    field :entity_type, :string
    field :created_at, :naive_datetime
    timestamps()
  end

  @required [:entity_id, :entity_type, :user_id, :user_type, :changes]
  @optional [:created_at]

  @doc false
  def changeset(log, attrs) do
    log
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
  end

  def create!(params) do
    %Log{}
    |> Log.changeset(params)
    |> Repo.insert!()
  end

  def update!(log, params) do
    log
    |> Log.changeset(params)
    |> Repo.update!()
  end

  def log(entity_id, entity_type, user_id, user_type, changes, created_at \\ NaiveDateTime.utc_now()) do
    params = %{
      "user_id" => user_id,
      "user_type" => user_type,
      "entity_id" => entity_id,
      "entity_type" => entity_type,
      "changes" => changes,
      "created_at" => created_at |> NaiveDateTime.truncate(:second)
    }

    %Log{}
    |> Log.changeset(params)
    |> Repo.insert!()
  end

  def get_logs(entity_id, entity_type, page) do
    entity_id = if is_binary(entity_id), do: String.to_integer(entity_id), else: entity_id
    page_no = if is_binary(page), do: String.to_integer(page), else: page
    limit = 20
    offset = (page_no - 1) * limit

    logs =
      Log
      |> where([l], l.entity_id == ^entity_id and l.entity_type == ^entity_type)
      |> where([l], fragment("changes != '{}'"))
      |> offset(^offset)
      |> limit(^limit)
      |> order_by([br], desc: br.inserted_at)
      |> Repo.all()

    logs =
      logs
      |> Enum.map(fn lg ->
        user_details =
          cond do
            String.downcase(lg.user_type) == "broker" ->
              broker_details =
                Broker.fetch_broker_from_ids([lg.user_id])
                |> Enum.reduce(%{}, fn broker, acc ->
                  locality_name =
                    if not is_nil(broker.polygon) do
                      if is_nil(broker.polygon.locality), do: nil, else: broker.polygon.locality.name
                    else
                      nil
                    end

                  Map.put(acc, broker.id, %{
                    "id" => broker.id,
                    "name" => broker.name,
                    "phone_number" => Broker.get_credential_data(broker)["phone_number"],
                    "profile_image_url" => Broker.get_profile_image_url(broker),
                    "locality_name" => locality_name
                  })
                end)

              broker_details

            String.downcase(lg.user_type) == "employee" ->
              user = Repo.get_by(EmployeeCredential, id: lg.user_id)

              %{
                "id" => user.id,
                "name" => user.name,
                "phone_number" => user.phone_number
              }

            true ->
              %{}
          end

        user_data =
          if not is_nil(user_details) do
            %{
              "id" => user_details["id"],
              "name" => user_details["name"],
              "phone_number" => user_details["phone_number"]
            }
          else
            %{}
          end

        %{
          "id" => lg.id,
          "entity_id" => lg.entity_id,
          "entity_type" => lg.entity_type,
          "user_id" => lg.user_id,
          "user_type" => lg.user_type,
          "user_details" => user_data,
          "changes" => lg.changes,
          "inserted_at" => lg.inserted_at
        }
      end)

    %{
      "logs" => logs,
      "next_page_exists" => Enum.count(logs) >= limit,
      "next_page_query_params" => "page=#{page_no + 1}"
    }
  end
end
