defmodule BnApis.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :name, :string
      add :display_address, :string
      add :developer_id, references(:developers, on_delete: :nothing)

      timestamps()
    end

    create index(:projects, [:developer_id])
  end
end
