defmodule BnApis.Repo.Migrations.CreateCommercialPropertyPocMappings do
  use Ecto.Migration

  def change do
    create table(:commercial_property_poc_mappings) do
      add :is_active, :boolean, default: true
      add :commercial_property_poc_id, references(:commercial_property_pocs)
      add :commercial_property_post_id, references(:commercial_property_posts)
      add :assigned_by_id, references(:employees_credentials, on_delete: :nothing)

      timestamps()
    end

    create unique_index(
             :commercial_property_poc_mappings,
             [:commercial_property_poc_id, :commercial_property_post_id, :is_active],
             where: "is_active = true",
             name: :commercial_property_post_poc_mappings_uniq_index
           )
  end
end
