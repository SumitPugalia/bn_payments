defmodule BnApis.Repo.Migrations.PanUniquenessInBrokersTable do
  use Ecto.Migration

  def change do
    create unique_index(:brokers, [:pan], name: :unique_pan_on_brokers)
  end
end
