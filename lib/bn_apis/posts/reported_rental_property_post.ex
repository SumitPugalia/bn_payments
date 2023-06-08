defmodule BnApis.Posts.ReportedRentalPropertyPost do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Posts.RentalPropertyPost
  alias BnApis.Accounts.Credential
  alias BnApis.Reasons.Reason
  alias BnApis.Posts.ReportedRentalPropertyPost
  alias BnApis.Accounts.EmployeeCredential

  schema "reported_rental_property_posts" do
    field :refreshed_on, :naive_datetime
    field :refresh_note, :string
    belongs_to :refreshed_by, EmployeeCredential
    belongs_to :rental_property, RentalPropertyPost
    belongs_to :reported_by, Credential
    belongs_to :report_post_reason, Reason

    timestamps()
  end

  @fields [:rental_property_id, :reported_by_id, :report_post_reason_id]
  @optional [:refreshed_on, :refreshed_by_id, :refresh_note]
  @required @fields

  @doc false
  def changeset(reported_rental_property_post, attrs) do
    reported_rental_property_post
    |> cast(attrs, @fields ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:reported_by_id, name: :b_re_reporting_not_allowed_index, message: "Post already reported!")
  end

  def report_post(
        params = %{
          post_id: post_id,
          reported_by_id: _user_id,
          report_post_reason_id: _reason_id
        }
      ) do
    params = params |> Map.merge(%{rental_property_id: post_id})

    %__MODULE__{}
    |> changeset(params)
    |> Repo.insert()
  end

  def get_reported_rental_property_ids(logged_user_id) do
    Repo.all(
      from rrpp in ReportedRentalPropertyPost,
        where: rrpp.reported_by_id == ^logged_user_id,
        select: rrpp.rental_property_id
    )
  end

  def refresh_posts(post_id, user_id, refresh_note) do
    try do
      rrpp =
        ReportedRentalPropertyPost
        |> where([rrpp], rrpp.rental_property_id == ^post_id)
        |> Repo.all()

      refreshed_on = Timex.now() |> DateTime.to_naive()

      rrpp
      |> Enum.each(fn rpp ->
        rpp
        |> ReportedRentalPropertyPost.changeset(%{
          "refreshed_on" => refreshed_on,
          "refreshed_by_id" => user_id,
          "refresh_note" => refresh_note
        })
        |> Repo.update!()
      end)

      {:ok, "Successfully refreshed reported post"}
    rescue
      err ->
        {:error, Exception.message(err)}
    end
  end

  def get_reported_rental_property_details(rental_property_id) do
    reports =
      ReportedRentalPropertyPost
      |> where([rrp], rrp.rental_property_id == ^rental_property_id)
      |> order_by([rrp], desc: rrp.inserted_at)
      |> preload([:reported_by, :report_post_reason, reported_by: [:broker]])
      |> Repo.all()
      |> Enum.map(fn rpp ->
        %{
          id: rpp.id,
          rental_property_id: rpp.rental_property_id,
          broker: %{
            id: rpp.reported_by.broker.id,
            name: rpp.reported_by.broker.name,
            phone_number: rpp.reported_by.phone_number
          },
          reason: %{
            id: rpp.report_post_reason.id,
            name: rpp.report_post_reason.name
          },
          refresh_note: rpp.refresh_note,
          refreshed_on: rpp.refreshed_on,
          refreshed_by_id: rpp.refreshed_by_id,
          created_at: rpp.inserted_at
        }
      end)

    first_report = reports |> List.last()
    last_report = reports |> List.first()
    first_reported_at = if not is_nil(first_report), do: first_report.created_at, else: nil
    last_reported_at = if not is_nil(last_report), do: last_report.created_at, else: nil
    %{first_reported_at: first_reported_at, last_reported_at: last_reported_at, reports: reports}
  end
end
