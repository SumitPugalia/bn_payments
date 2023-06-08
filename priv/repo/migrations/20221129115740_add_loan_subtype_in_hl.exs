defmodule BnApis.Repo.Migrations.AddLoanSubtypeInHl do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      add(:loan_subtype, :string)
      add(:loan_amount_by_agent, :bigint)
    end
  end
end
