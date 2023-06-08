defmodule BnApis.Repo.Migrations.AddUpiIdToAccounts do
  use Ecto.Migration

  def change do
    alter table(:credentials) do
      add :upi_id, :string
    end

    alter table(:employees_credentials) do
      add :upi_id, :string
    end
  end
end
