defmodule BnApis.Repo.Migrations.DropIndexOnWhitelistedBrokersInfo do
  use Ecto.Migration

  def change do
    drop_if_exists index(:whitelisted_brokers_info, [:phone_number])
  end
end
