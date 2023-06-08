defmodule BnApis.Repo.Migrations.CreateCommercialPropertyStatusLog do
  use Ecto.Migration

  def change do
    create table(:commercial_property_status_log) do
      add(:status_from, :string)
      add(:status_to, :string)
      add(:comment, :text)
      add(:active, :boolean, default: true)
      add(:commercial_property_post_id, references(:commercial_property_posts), null: false)
      add(:created_by_id, references(:employees_credentials), null: false)
      timestamps()
    end
  end
end
