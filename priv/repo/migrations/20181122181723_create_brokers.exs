defmodule BnApis.Repo.Migrations.CreateBrokers do
  use Ecto.Migration

  def change do
    create table(:brokers) do
      add :name, :string
      add :profile_image, :map

      timestamps()
    end
  end
end
