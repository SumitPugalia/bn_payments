defmodule BnApis.Repo.Migrations.CreateHomeloanLeads do
  use Ecto.Migration

  def change do
    create table(:homeloan_leads) do
      add(:name, :string, null: false)
      add(:phone_number, :string, null: false)
      add(:country_id, references(:countries), null: false)
      add(:broker_id, references(:brokers), null: false)
      timestamps()
    end
  end
end
