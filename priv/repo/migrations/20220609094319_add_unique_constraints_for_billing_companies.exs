defmodule BnApis.Repo.Migrations.AddUniqueConstraintsForBillingCompanies do
  use Ecto.Migration

  def change do
    create(
      unique_index(
        :bank_accounts,
        [:account_number, :active],
        where: "active = true",
        name: :unique_bank_account_number_index
      )
    )

    create(
      unique_index(
        :billing_companies,
        [:pan],
        name: :unique_pan_index
      )
    )
  end
end
