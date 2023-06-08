defmodule BnApis.Repo.Migrations.AddUniqueConstraintForPaymentId do
  use Ecto.Migration

  def change do
    create unique_index(:payments, [:payment_id, :payment_status])
  end
end
