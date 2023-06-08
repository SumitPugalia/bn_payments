defmodule BnApis.Repo.Migrations.CredentialUuidIndex do
  use Ecto.Migration

  def change do
    create unique_index(:credentials, [:uuid])
    create unique_index(:employees_credentials, [:uuid])
    create unique_index(:developers_credentials, [:uuid])
    create unique_index(:developer_poc_credentials, [:uuid])
  end
end
