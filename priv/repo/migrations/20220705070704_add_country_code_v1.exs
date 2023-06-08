defmodule BnApis.Repo.Migrations.AddCountryCodeV1 do
  use Ecto.Migration

  def change do
    alter table(:credentials) do
      add :country_code, :string, default: "+91", null: false
    end

    alter table(:developer_poc_credentials) do
      add :country_code, :string, default: "+91", null: false
    end

    alter table(:employees_credentials) do
      add :country_code, :string, default: "+91", null: false
    end

    alter table(:brokers_invites) do
      add :country_code, :string, default: "+91", null: false
    end

    alter table(:whitelisted_numbers) do
      add :country_code, :string, default: "+91", null: false
    end

    alter table(:call_logs) do
      add :country_code, :string, default: "+91", null: false
    end

    alter table(:brokers_universe) do
      add :country_code, :string, default: "+91", null: false
    end

    alter table(:stories_call_logs) do
      add :country_code, :string, default: "+91", null: false
    end

    alter table(:whitelisted_brokers_info) do
      add :country_code, :string, default: "+91", null: false
    end
  end
end
