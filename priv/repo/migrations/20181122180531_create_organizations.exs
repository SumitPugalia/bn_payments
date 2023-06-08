defmodule BnApis.Repo.Migrations.CreateOrganizations do
  use Ecto.Migration

  def change do
    create table(:organizations) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :name, :string, null: false
      add :gst_number, :string
      add :rera_id, :string

      timestamps()
    end

    create index(:organizations, [:uuid])
    create unique_index(:organizations, [:gst_number])
    create unique_index(:organizations, [:rera_id])

    create unique_index(:organizations, [:name, :gst_number, :rera_id],
             name: :organizations_name_rera_gst_id_index
           )
  end
end
