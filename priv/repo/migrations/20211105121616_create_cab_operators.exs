defmodule BnApis.Repo.Migrations.CreateCabOperators do
  use Ecto.Migration

  def change do
    create table(:cab_operators) do
      add :name, :string
      timestamps()
    end
  end
end
