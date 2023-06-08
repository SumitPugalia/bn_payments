defmodule BnApis.Repo.Migrations.AddIsBrokerToOwners do
  use Ecto.Migration

  def change do
    alter table(:owners) do
      add(:is_broker, :boolean, default: false)
    end
  end
end
