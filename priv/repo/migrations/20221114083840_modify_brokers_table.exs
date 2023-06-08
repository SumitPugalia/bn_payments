defmodule BnApis.Repo.Migrations.ModifyBrokersTable do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      add(:kyc_status, :string, default: "missing")
      add(:change_notes, :string)
      add(:is_pan_verified, :boolean, default: false)
      add(:is_rera_verified, :boolean, default: false)
    end

    create index(:brokers, [:kyc_status])
  end
end
