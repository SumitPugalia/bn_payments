defmodule BnApis.Repo.Migrations.CreateCountries do
  use Ecto.Migration

  def change do
    create table(:countries) do
      add(:name, :string, null: false)
      add(:country_code, :string, null: false)
      add(:url_name, :string, null: false)
      add(:is_operational, :boolean, null: false, default: false)
      add(:phone_validation_regex, :string, null: false)
      add(:order, :integer, null: false)
      timestamps()
    end

    create(unique_index(:countries, [:url_name]))
  end
end
