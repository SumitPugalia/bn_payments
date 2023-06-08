defmodule BnApis.Repo.Migrations.CreateBrokersTypes do
  use Ecto.Migration

  def change do
    create table(:brokers_types) do
      add :name, :string

      timestamps()
    end
  end
end
