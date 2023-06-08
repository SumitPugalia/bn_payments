defmodule BnApis.Commercials.ReportedCommercialPropertyPost do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Accounts.Credential
  alias BnApis.Reasons.Reason
  alias BnApis.Commercials.CommercialPropertyPost
  alias BnApis.Commercials.ReportedCommercialPropertyPost
  alias BnApis.Organizations.Broker

  schema "reported_commercial_property_posts" do
    field :remarks, :string
    belongs_to :commercial_property_post, CommercialPropertyPost
    belongs_to :reported_by, Credential
    belongs_to :report_property_post_reason, Reason

    timestamps()
  end

  @required [:commercial_property_post_id, :reported_by_id, :report_property_post_reason_id]
  @optional [:remarks]

  @doc false
  def changeset(reported_commercial_property, attrs) do
    reported_commercial_property
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:reported_by_id,
      name: :commercial_post_re_reporting_not_allowed_index,
      message: "Commercial Property post already reported!"
    )
  end

  def report_post(post_id, user_id, reason_id, remarks) do
    report_post = Repo.get_by(ReportedCommercialPropertyPost, reported_by_id: user_id, commercial_property_post_id: post_id)

    if is_nil(report_post) do
      report_post_params = %{
        "remarks" => remarks,
        "commercial_property_post_id" => post_id,
        "reported_by_id" => user_id,
        "report_property_post_reason_id" => reason_id
      }

      %ReportedCommercialPropertyPost{}
      |> changeset(report_post_params)
      |> Repo.insert()
    else
      {:error, "Property already reported"}
    end
  end

  def get_reported_post(post_id) do
    ReportedCommercialPropertyPost
    |> join(:inner, [c], r in Reason, on: r.id == c.report_property_post_reason_id)
    |> join(:inner, [c, r], cr in Credential, on: cr.id == c.reported_by_id)
    |> join(:inner, [c, r, cr], b in Broker, on: b.id == cr.broker_id)
    |> where([c, r, cr, b], c.commercial_property_post_id == ^post_id)
    |> order_by([c], desc: c.inserted_at)
    |> select([c, r, cr, b], %{
      id: c.id,
      remarks: c.remarks,
      commercial_property_post_id: c.commercial_property_post_id,
      reported_by_id: c.reported_by_id,
      reported_by_name: b.name,
      reported_by_phone: cr.phone_number,
      report_property_post_reason_id: c.report_property_post_reason_id,
      reported_on:
        fragment(
          """
          cast(date_part('epoch', ?) as integer)
          """,
          c.inserted_at
        )
    })
    |> Repo.all()
  end

  def get_reported_data(post_id) do
    reports = ReportedCommercialPropertyPost.get_reported_post(post_id)
    last_reported_on = if not is_nil(reports) and length(reports) > 0, do: List.first(reports).reported_on, else: nil
    first_reported_on = if not is_nil(reports) and length(reports) > 0, do: List.last(reports).reported_on, else: nil
    {reports, last_reported_on, first_reported_on}
  end

  def get_id_of_reported_post() do
    ReportedCommercialPropertyPost |> Repo.all() |> Enum.map(& &1.commercial_property_post_id) |> Enum.uniq()
  end
end
