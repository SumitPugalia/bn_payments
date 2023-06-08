defmodule BnApis.Repo.Migrations.AddEmailAndCountryCodeInOwners do
  use Ecto.Migration

  def change do
    alter table(:owners) do
      add(:email, :string)
      add(:country_code, :string)
    end
  end
end
