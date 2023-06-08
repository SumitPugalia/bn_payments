defmodule BnApis.Repo.Migrations.CreateCommercialPropertyPocs do
  use Ecto.Migration

  def change do
    create table(:commercial_property_pocs) do
      add :name, :string
      add :email, :string
      add :phone, :string
      add :country_code, :string
      add :type, :string
      timestamps()
    end

    create unique_index(:commercial_property_pocs, [:phone])
  end
end
