defmodule BnApis.Repo.Migrations.AddFraudCheckColumns do
  use Ecto.Migration

  def change do
    alter table(:credentials) do
      add(:upi_name, :string)
    end

    alter table(:brokers) do
      add(:pan_name, :string)
    end

    # drop_if_exists unique_index(:credentials, ["lower(upi_id)"],
    #                  where: "active = true AND upi_id IS NOT NULL",
    #                  name: "unique_upi_on_credentials"
    #                )
    #
    # create unique_index(:credentials, ["lower(upi_id)"],
    #          where: "active = true AND upi_id IS NOT NULL",
    #          name: "unique_upi_on_credentials"
    #        )
    #
    # drop_if_exists unique_index(:brokers, ["lower(pan)"],
    #                  where: "pan IS NOT NULL",
    #                  name: "unique_pan_on_brokers"
    #                )
    #
    # create unique_index(:brokers, ["lower(pan)"],
    #          where: "pan IS NOT NULL",
    #          name: "unique_pan_on_brokers"
    #        )
  end
end
