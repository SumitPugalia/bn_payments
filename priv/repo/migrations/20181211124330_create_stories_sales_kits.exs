defmodule BnApis.Repo.Migrations.CreateStoriesSalesKits do
  use Ecto.Migration

  def change do
    create table(:stories_sales_kits) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :name, :string
      add :thumbnail, :string
      add :share_url, :string
      add :preview_url, :string
      add :size_in_mb, :decimal
      add :attachment_type_id, references(:stories_attachment_types, on_delete: :nothing)
      add :story_id, references(:stories, on_delete: :nothing)

      timestamps()
    end

    create index(:stories_sales_kits, [:attachment_type_id])
    create index(:stories_sales_kits, [:story_id])
  end
end
