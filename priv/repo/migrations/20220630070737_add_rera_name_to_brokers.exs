defmodule BnApis.Repo.Migrations.AddReraNameToBrokers do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      add(:rera_name, :string)
    end
  end
end
