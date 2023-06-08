defmodule BnApis.Repo.Migrations.AddKitUrlsAndPanInBrokers do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      add(:pan, :string)
      add(:portrait_kit_url, :string)
      add(:landscape_kit_url, :string)
    end
  end
end
