defmodule BnApis.Repo.Migrations.CreateUserOrderTable do
  use Ecto.Migration

  def change do
    create table(:user_orders, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :amount, :integer, null: false
      add :amount_paid, :integer, null: false
      add :amount_due, :integer, null: false
      add :created_at, :integer, null: false
      add :currency, :string, null: false
      add :status, :string, null: false
      add :is_client_side_payment_successful, :boolean
      add :is_captured, :boolean
      add :notes, :string
      add :pg_order_id, :string
      add :pg_request, :map, default: %{}
      add :pg_response, :map, default: %{}
      add :broker_id, references(:brokers, on_delete: :nothing)

      timestamps()
    end
  end
end
