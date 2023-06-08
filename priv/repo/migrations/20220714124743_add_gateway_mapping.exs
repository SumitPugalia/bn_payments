defmodule BnApis.Repo.Migrations.AddGatewayMapping do
  use Ecto.Migration

  def change do
    create table(:gateway_to_city_mapping, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :city_ids, {:array, :integer}
      add :active, :boolean, null: false
      add :name, :string, null: false

      timestamps()
    end

    create table(:client_to_gateway_payout_mapping, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :payment_gateway_id, references(:gateway_to_city_mapping, type: :uuid), null: false
      add :contact_id, :string, null: false
      add :fund_account_id, :string, null: false
      add :active, :boolean
      add :cilent_uuid, :uuid, null: false

      timestamps()
    end
  end
end
