defmodule BnApis.Repo.Migrations.AddUniqueIndexInWhitelistedBrokerInfo do
  use Ecto.Migration

  def change do
    create unique_index(:whitelisted_brokers_info, [:phone_number])
  end
end
