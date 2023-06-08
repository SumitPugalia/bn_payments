defmodule BnApis.Campaign.Schema.CampaignLeads do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo

  @fields ~w(campaign_id broker_id delivered sent shown action_taken retries)a

  schema "campaign_leads" do
    field :campaign_id, :integer
    field :broker_id, :integer
    field :delivered, :boolean
    field :sent, :boolean
    field :shown, :boolean
    field :action_taken, :boolean
    field :retries, :integer

    timestamps()
  end

  def new(params), do: changeset(%__MODULE__{}, params)

  def changeset(struct, params) do
    struct
    |> cast(params, @fields)
    |> validate_required(@fields)
    |> foreign_key_constraint(:campaign_id)
    |> foreign_key_constraint(:broker_id)
    |> unique_constraint([:campaign_id, :broker_id], name: :unique_broker_for_campaign_index)
  end

  def update_campaign_stats(campaign_id, broker_id, action) when action in ~w(shown action_taken delivered)a do
    __MODULE__
    |> where([cl], cl.campaign_id == ^campaign_id and cl.broker_id == ^broker_id)
    |> update(set: [{^action, true}, {:updated_at, ^NaiveDateTime.utc_now()}])
    |> Repo.update_all([])
  end

  def update_campaign_stats(_campaign_id, _broker_id, _action), do: nil
end
