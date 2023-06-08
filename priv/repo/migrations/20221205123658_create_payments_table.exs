defmodule BnApis.Repo.Migrations.CreateUserPackagePaymentsTable do
  use Ecto.Migration

  def change do
    create table(:payments) do
      add(:payment_id, :string, null: false)
      add(:payment_status, :string, null: false)
      add(:amount, :integer, null: false)
      add(:currency, :string, null: false)
      add(:created_at, :integer, null: false)
      add(:payment_data, :map)
      add(:payment_gateway, :string, null: false)
      add(:international, :boolean)
      add(:method, :string)
      add(:amount_refunded, :integer)
      add(:refund_status, :string)
      add(:captured, :boolean)
      add(:description, :string)
      add(:payment_method_type, :string)
      add(:tax, :integer)
      add(:fee, :integer)
      add(:email, :string)
      add(:contact, :string)
      add(:notes, :string)
      add :user_order_id, references(:user_orders, on_delete: :nothing, type: :uuid), null: false

      timestamps()
    end
  end
end
