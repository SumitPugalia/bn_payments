defmodule BnApis.Repo.Migrations.CreateScrapeInfo do
  use Ecto.Migration

  def change do
    create table(:scrap_info) do
      add :name, :string, null: false
      add :date, :date, nul: false
      add :offset, :string
    end
  end
end
