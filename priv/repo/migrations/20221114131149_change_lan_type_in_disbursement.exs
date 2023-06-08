defmodule BnApis.Repo.Migrations.ChangeLanTypeInDisbursement do
  use Ecto.Migration

  def change do
    alter table(:loan_disbursements) do
      modify(:lan, :string)
    end
  end
end
