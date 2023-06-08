defmodule BnApis.Repo.Migrations.AddBookingPaymentTable do
  use Ecto.Migration

  def change do
    create table(:booking_payment) do
      add :token_amount, :integer
      add :payment_mode, :string
      add :payment_proof, :string

      timestamps()
    end
  end
end
