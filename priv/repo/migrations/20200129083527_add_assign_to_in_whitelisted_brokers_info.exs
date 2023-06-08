defmodule BnApis.Repo.Migrations.AddAssignToInWhitelistedBrokersInfo do
  use Ecto.Migration

  def change do
    alter table(:whitelisted_brokers_info) do
      add :assign_to, :string
    end
  end
end
