defmodule BnApis.Repo.Migrations.AddDisbursedWithInHl do
  use Ecto.Migration

  def change do
    alter table(:loan_disbursements) do
      add(:disbursed_with, :string)
    end
  end
end
