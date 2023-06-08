defmodule BnApis.Repo.Migrations.AddBookingRewardsLeadsTable do
  use Ecto.Migration

  def change do
    create table(:booking_rewards_leads) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :booking_date, :integer
      add :booking_form_number, :string
      add :rera_number, :string
      add :unit_number, :string
      add :rera_carpet_area, :integer
      add :building_name, :string
      add :wing, :string
      add :agreement_value, :integer
      add :agreement_proof, :string
      add :invoice_number, :string
      add :invoice_date, :integer
      add :status_id, :integer
      add :status_message, :string
      add :deleted, :boolean, default: false
      add :story_id, references(:stories, on_delete: :nothing)
      add :broker_id, references(:brokers, on_delete: :nothing)
      add :booking_client_id, references(:booking_client, on_delete: :nothing)
      add :booking_payment_id, references(:booking_payment, on_delete: :nothing)
      add :billing_company_id, references(:billing_companies, on_delete: :nothing)
      add :legal_entity_id, references(:legal_entities, on_delete: :nothing)

      timestamps()
    end

    create unique_index(
             :booking_rewards_leads,
             [:story_id, :booking_form_number, :wing, :unit_number, :deleted],
             name: :booking_rewards_lead_unique_index
           )
  end
end
