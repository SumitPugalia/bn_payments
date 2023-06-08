defmodule BnApis.Repo.Migrations.CreateDevelopers do
  use Ecto.Migration

  def change do
    create table(:developers) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :name, :string
      add :logo_url, :string
      add :micro_market_id, references(:micro_markets, on_delete: :nothing)

      timestamps()
    end

    create index(:developers, [:micro_market_id])
  end
end
