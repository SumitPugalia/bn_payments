defmodule BnApis.Repo.Migrations.CreateCommercialPropertyLogs do
  use Ecto.Migration

  def change do
    create table(:commercial_property_logs) do
      add :changes, :map
      add :user_id, :integer
      add :user_type, :string
      add :commercial_property_post_id, references(:commercial_property_posts), null: false
      timestamps()
    end
  end
end
