defmodule BnApis.Repo.Migrations.AddOldBrokerId do
  use Ecto.Migration

  def change do
    alter table(:booking_rewards_leads) do
      add :old_broker_id, references(:brokers)
      add :old_organization_id, references(:organizations)
    end

    alter table(:invoices) do
      add :old_broker_id, references(:brokers)
      add :old_organization_id, references(:organizations)
    end

    alter table(:homeloan_leads) do
      add :old_broker_id, references(:brokers)
      add :old_organization_id, references(:organizations)
    end

    alter table(:cab_booking_requests) do
      add :old_broker_id, references(:brokers)
      add :old_organization_id, references(:organizations)
    end

    alter table(:billing_companies) do
      add :old_broker_id, references(:brokers)
      add :old_organization_id, references(:organizations)
    end
  end
end
