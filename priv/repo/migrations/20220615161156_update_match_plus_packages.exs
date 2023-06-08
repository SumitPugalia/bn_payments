defmodule BnApis.Repo.Migrations.UpdateMatchPlusPackages do
  use Ecto.Migration

  def change do
    alter table(:match_plus_packages) do
      add(:autopay, :boolean, default: false)
      add(:city_id, references(:cities), null: true)
    end
  end
end
