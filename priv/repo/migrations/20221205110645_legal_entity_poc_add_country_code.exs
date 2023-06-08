defmodule BnApis.Repo.Migrations.LegalEntityPocAddCountryCode do
  use Ecto.Migration

  def change do
    alter table(:legal_entity_pocs) do
      add :country_code, :string, default: "+91", null: false
      add :active, :boolean, default: true, null: false
      add :last_active_at, :naive_datetime
    end
  end
end
