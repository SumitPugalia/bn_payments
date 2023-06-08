defmodule BnApis.Repo.Migrations.AddEmailAddressInEmployeesCredentials do
  use Ecto.Migration

  def change do
    alter table(:employees_credentials) do
      add(:email, :string)
    end
  end
end
