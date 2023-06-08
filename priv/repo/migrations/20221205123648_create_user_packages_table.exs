defmodule BnApis.Repo.Migrations.CreateUserPackagesTable do
  use Ecto.Migration

  def change do
    create table(:user_packages, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :status, :string, null: false
      add :current_start, :integer, null: false
      add :current_end, :integer, null: false

      add :user_order_id, references(:user_orders, on_delete: :nothing, type: :uuid), null: false
      add :broker_id, references(:brokers, on_delete: :nothing)
      add :match_plus_package_id, references(:match_plus_packages, on_delete: :nothing)

      timestamps()
    end
  end
end
