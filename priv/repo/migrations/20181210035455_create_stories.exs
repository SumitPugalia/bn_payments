defmodule BnApis.Repo.Migrations.CreateStories do
  use Ecto.Migration

  def change do
    create table(:stories) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :name, :string
      add :interval, :integer
      add :favourite_at, :naive_datetime
      add :archived, :boolean, default: false, null: false
      add :image_url, :string
      add :developer_id, references(:developers, on_delete: :nothing)

      timestamps()
    end

    create index(:stories, [:developer_id])
  end
end
