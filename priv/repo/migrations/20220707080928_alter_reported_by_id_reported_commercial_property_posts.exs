defmodule BnApis.Repo.Migrations.AlterReportedByIdReportedCommercialPropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:reported_commercial_property_posts) do
      remove :reported_by_id
      remove :remarks
      add(:remarks, :text)
      add :reported_by_id, references(:credentials)
    end
  end
end
