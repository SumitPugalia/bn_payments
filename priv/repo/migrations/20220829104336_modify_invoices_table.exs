defmodule BnApis.Repo.Migrations.ModifyInvoicesTable do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      add(:is_created_by_piramal, :boolean, default: false)
    end
  end
end
