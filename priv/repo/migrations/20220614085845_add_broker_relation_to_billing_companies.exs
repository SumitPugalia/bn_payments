defmodule BnApis.Repo.Migrations.AddBrokerRelationToBillingCompanies do
  use Ecto.Migration

  def change do
    alter table(:billing_companies) do
      add(:broker_id, references(:brokers))
    end

    drop_if_exists index(:billing_companies, [:pan], name: :unique_pan_index)

    create(
      unique_index(
        :billing_companies,
        ["lower(pan)"],
        name: :unique_pan_billing_companies_index
      )
    )
  end
end
