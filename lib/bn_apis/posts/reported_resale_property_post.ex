defmodule BnApis.Posts.ReportedResalePropertyPost do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Posts.ResalePropertyPost
  alias BnApis.Accounts.Credential
  alias BnApis.Reasons.Reason
  alias BnApis.Posts.ReportedResalePropertyPost
  alias BnApis.Accounts.EmployeeCredential

  schema "reported_resale_property_posts" do
    field :refreshed_on, :naive_datetime
    field :refresh_note, :string
    belongs_to :refreshed_by, EmployeeCredential
    belongs_to :resale_property, ResalePropertyPost
    belongs_to :reported_by, Credential
    belongs_to :report_post_reason, Reason

    timestamps()
  end

  @fields [:resale_property_id, :reported_by_id, :report_post_reason_id]
  @optional [:refreshed_on, :refreshed_by_id, :refresh_note]
  @required @fields

  @doc false
  def changeset(reported_resale_property_post, attrs) do
    reported_resale_property_post
    |> cast(attrs, @fields ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:reported_by_id, name: :d_re_reporting_not_allowed_index, message: "Post already reported!")
  end

  def report_post(
        params = %{
          post_id: post_id,
          reported_by_id: _user_id,
          report_post_reason_id: _reason_id
        }
      ) do
    params = params |> Map.merge(%{resale_property_id: post_id})

    %__MODULE__{}
    |> changeset(params)
    |> Repo.insert()
  end

  def get_reported_resale_property_post_ids(logged_user_id) do
    Repo.all(
      from rrpp in ReportedResalePropertyPost,
        where: rrpp.reported_by_id == ^logged_user_id,
        select: rrpp.resale_property_id
    )
  end

  def refresh_posts(post_id, user_id, refresh_note) do
    try do
      rrpp =
        ReportedResalePropertyPost
        |> where([rrpp], rrpp.resale_property_id == ^post_id)
        |> Repo.all()

      refreshed_on = Timex.now() |> DateTime.to_naive()

      rrpp
      |> Enum.each(fn rpp ->
        rpp
        |> ReportedResalePropertyPost.changeset(%{
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

  def get_reported_resale_property_details(resale_property_id) do
    reports =
      ReportedResalePropertyPost
      |> where([rrp], rrp.resale_property_id == ^resale_property_id)
      |> order_by([rrp], desc: rrp.inserted_at)
      |> preload([:reported_by, :report_post_reason, reported_by: [:broker]])
      |> Repo.all()
      |> Enum.map(fn rpp ->
        %{
          id: rpp.id,
          resale_property_id: rpp.resale_property_id,
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
