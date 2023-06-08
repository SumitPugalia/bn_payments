defmodule BnApis.Repo.Migrations.CreateMasterPlusPackages do
  use Ecto.Migration

  def change do
    create table(:match_plus_packages) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add(:status_id, :integer, null: false)
      add(:amount_in_rupees, :integer, null: false)
      add(:validity_in_days, :integer, null: false)

      timestamps()
    end
  end
end
