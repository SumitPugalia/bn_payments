defmodule BnApis.Repo.Migrations.ModifyStoriesTable do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add(:has_mandate_company, :boolean, default: false)
      add(:mandate_company_id, references(:mandate_companies))
    end
  end
end
