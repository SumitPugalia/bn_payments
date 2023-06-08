defmodule BnApis.Repo.Migrations.AddUuidToTransactionData do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      remove :area
      add :area, :decimal
    end
  end
end
