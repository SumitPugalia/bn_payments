defmodule BnApis.Campaign.Schema.Campaign do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Campaign.Schema.CampaignLeads

  @required_fields ~w(campaign_identifier start_date end_date executed_sql type data)a
  @fields @required_fields ++ ~w(active)a

  schema "campaign" do
    field :campaign_identifier, :string
    field :start_date, :integer
    field :end_date, :integer
    # Keep historical record of the query used to run campaign.
    field :executed_sql, :string
    field :type, :string
    field :active, :boolean
    field :data, :map

    has_many(:campaign_leads, CampaignLeads)

    timestamps()
  end

  def new(params), do: changeset(%__MODULE__{}, params)

  def changeset(struct, params) do
    struct
    |> cast(params, @fields)
    |> validate_required(@required_fields)
    |> ensure_start_date_gt_end_date()
    |> unique_constraint(:campaign_identifier, name: :campaign_identifier_index)
  end

  defp ensure_start_date_gt_end_date(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    try do
      if DateTime.diff(DateTime.from_unix!(end_date), DateTime.from_unix!(start_date), :second) > 120,
        do: changeset,
        else: add_error(changeset, :datetime, "start date must be greater than end date by an hour")
    rescue
      _ -> add_error(changeset, :datetime, "invalid start or end date")
    end
  end
end
