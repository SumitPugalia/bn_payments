defmodule BnApis.Repo.Migrations.CreateLeadDumpTable do
  use Ecto.Migration

  def change do
    create table(:lead_dump) do
      add :name, :string
      add :phone, :string
      add :email, :string
      add :metadata, :jsonb

      timestamps()
    end
  end
end
