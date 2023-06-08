defmodule BnApis.Repo.Migrations.AddRoleTypeInPocApprovals do
  use Ecto.Migration

  def change do
    alter table(:poc_invoice_approvals) do
      add :role_type, :string
      add :ip, :string
    end
  end
end
