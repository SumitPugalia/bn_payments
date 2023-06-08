defmodule BnApis.Repo.Migrations.AddBankOfferDocInLoanFiles do
  use Ecto.Migration

  def change do
    alter table(:loan_files) do
      add(:rejected_lost_reason, :string)
      add(:rejected_doc_url, :string)
      add(:bank_offer_doc_url, :string)
    end

    create unique_index(:loan_files, [:lan])
    create unique_index(:loan_files, [:application_id])
  end
end
