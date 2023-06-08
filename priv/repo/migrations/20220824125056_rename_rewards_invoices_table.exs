defmodule BnApis.Repo.Migrations.RenameRewardsInvoicesTable do
  use Ecto.Migration

  def change do
    rename table("rewards_invoices"), to: table("booking_invoices")
  end
end
