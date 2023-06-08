defmodule BnApis.Repo.Migrations.AddOperatingCityForBroker do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      add :operating_city, :integer
    end
  end
end
