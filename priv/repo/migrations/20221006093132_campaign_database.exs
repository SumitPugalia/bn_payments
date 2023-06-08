defmodule BnApis.Repo.Migrations.CampaignDatabase do
  use Ecto.Migration

  def change do
    create table(:campaign) do
      add :campaign_identifier, :string
      add :start_date, :bigint
      add :end_date, :bigint
      add :executed_sql, :text
      add :active, :boolean, default: true
      add :type, :string
      timestamps()
    end

    create table(:campaign_leads) do
      add :campaign_id, references(:campaign)
      add :broker_id, references(:brokers)
      add :delivered, :boolean, default: false
      add :sent, :boolean, default: false
      add :shown, :boolean, default: false
      add :action_taken, :boolean, default: false
      add :retries, :integer, default: 0
      timestamps()
    end

    create unique_index(:campaign, [:campaign_identifier], name: :campaign_identifier_index)
  end
end
