defmodule BnApis.Reasons.Reason do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Reasons.ReasonType
  alias BnApis.Reasons.Reason

  def seed_data do
    [
      %{
        id: 1,
        name: "Deal was done through this app",
        reason_type_id: ReasonType.delete_post_client().id
      },
      %{
        id: 2,
        name: "Deal was done through other app",
        reason_type_id: ReasonType.delete_post_client().id
      },
      %{
        id: 3,
        name: "Other reason",
        reason_type_id: ReasonType.delete_post_client().id
      },
      %{
        id: 4,
        name: "Deal was done through this app",
        reason_type_id: ReasonType.delete_post_property().id
      },
      %{
        id: 5,
        name: "Deal was done through other app",
        reason_type_id: ReasonType.delete_post_property().id
      },
      %{
        id: 6,
        name: "Other reason",
        reason_type_id: ReasonType.delete_post_property().id
      },
      %{
        id: 7,
        name: "One or more listings had expired",
        reason_type_id: ReasonType.block_broker().id
      },
      %{
        id: 8,
        name: "Broker was rude",
        reason_type_id: ReasonType.block_broker().id
      },
      %{
        id: 9,
        name: "Other reason",
        reason_type_id: ReasonType.block_broker().id
      },
      %{
        id: 10,
        name: "Property / client expired",
        reason_type_id: ReasonType.report_post().id
      },
      %{
        id: 11,
        name: "Fake post",
        reason_type_id: ReasonType.report_post().id
      },
      %{
        id: 12,
        name: "Other",
        reason_type_id: ReasonType.report_post().id
      },
      %{
        id: 13,
        name: "Property sold out / rented out",
        reason_type_id: ReasonType.report_owner_post().id
      },
      %{
        id: 14,
        name: "Not an owner",
        reason_type_id: ReasonType.report_owner_post().id
      },
      %{
        id: 15,
        name: "Not responding",
        reason_type_id: ReasonType.report_owner_post().id
      },
      %{
        id: 16,
        name: "Incorrect information",
        reason_type_id: ReasonType.report_owner_post().id
      },
      %{
        id: 17,
        name: "Incorrect contact details",
        reason_type_id: ReasonType.report_commercial_post().id
      },
      %{
        id: 18,
        name: "Property not available",
        reason_type_id: ReasonType.report_commercial_post().id
      },
      %{
        id: 19,
        name: "No response",
        reason_type_id: ReasonType.report_commercial_post().id
      },
      %{
        id: 20,
        name: "Customer cancelled",
        reason_type_id: ReasonType.report_commercial_site_visit().id
      },
      %{
        id: 21,
        name: "Not interested anymore",
        reason_type_id: ReasonType.report_commercial_site_visit().id
      },
      %{
        id: 22,
        name: "Finalized other property",
        reason_type_id: ReasonType.report_commercial_site_visit().id
      },
      %{
        id: 23,
        name: "Client not interested",
        reason_type_id: ReasonType.delete_bucket().id
      },
      %{
        id: 24,
        name: "Client requirements fulfilled through BN",
        reason_type_id: ReasonType.delete_bucket().id
      },
      %{
        id: 25,
        name: "Client has finalised some other property",
        reason_type_id: ReasonType.delete_bucket().id
      },
      %{
        id: 26,
        name: "Not required anymore",
        reason_type_id: ReasonType.delete_bucket().id
      },
      %{
        id: 27,
        name: "Post Deactivated By Bot",
        reason_type_id: ReasonType.delete_post_property().id
      },
      %{
        id: 28,
        name: "Plan Changed",
        reason_type_id: ReasonType.delete_post_property().id
      },
      %{
        id: 29,
        name: "Not Interested",
        reason_type_id: ReasonType.delete_post_property().id
      },
      %{
        id: 30,
        name: "Not Ready To Pay Brokerage",
        reason_type_id: ReasonType.delete_post_property().id
      },
      %{
        id: 31,
        name: "Wrong Number",
        reason_type_id: ReasonType.delete_post_property().id
      },
      %{
        id: 32,
        name: "Wrong Details Posted By Associate",
        reason_type_id: ReasonType.delete_post_property().id
      },
      %{
        id: 33,
        name: "Broker Property",
        reason_type_id: ReasonType.delete_post_property().id
      },
      %{
        id: 34,
        name: "Deactivated After Multiple Attempts",
        reason_type_id: ReasonType.delete_post_property().id
      },
      %{
        id: 35,
        name: "Duplicate Property",
        reason_type_id: ReasonType.delete_post_property().id
      },
      %{
        id: 36,
        name: "Incorrect Property Details",
        reason_type_id: ReasonType.delete_post_property().id
      },
      %{
        id: 37,
        name: "Not An Owner",
        reason_type_id: ReasonType.delete_post_property().id
      },
      %{
        id: 38,
        name: "Post Refreshed By Bot",
        reason_type_id: ReasonType.refresh_post_property().id
      },
      %{
        id: 39,
        name: "Broker had call",
        reason_type_id: ReasonType.refresh_post_property().id
      },
      %{
        id: 40,
        name: "Broker Had Not Call",
        reason_type_id: ReasonType.refresh_post_property().id
      },
      %{
        id: 41,
        name: "Other",
        reason_type_id: ReasonType.refresh_post_property().id
      },
      %{
        id: 42,
        name: "SPAM Property",
        reason_type_id: ReasonType.delete_post_property().id
      }
    ]
  end

  @primary_key false
  schema "reasons" do
    field :id, :integer, primary_key: true
    field :name, :string
    belongs_to :reason_type, ReasonType

    timestamps()
  end

  @doc false
  def changeset(reason, attrs) do
    reason
    |> cast(attrs, [:id, :name, :reason_type_id])
    |> validate_required([:id, :name, :reason_type_id])
    |> unique_constraint(:name)
  end

  def changeset(params) do
    %__MODULE__{}
    |> changeset(params)
  end

  def get_reasons_by_type(reason_type_id) do
    Reason
    |> where([r], r.reason_type_id == ^reason_type_id)
    |> select([r], %{
      id: r.id,
      name: r.name
    })
    |> Repo.all()
  end
end
