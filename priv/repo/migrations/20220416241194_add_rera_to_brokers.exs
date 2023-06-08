defmodule BnApis.Repo.Migrations.AddReraToBrokers do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      add :rera_file, :map
      add :rera, :string
    end
  end
end
