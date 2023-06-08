defmodule BnApis.Repo.Migrations.ChangeUrlType do
  use Ecto.Migration

  def change do
    alter table(:billing_companies) do
      modify :signature, :text, from: :string
    end

    alter table(:bank_accounts) do
      modify :cancelled_cheque, :text, from: :string
    end
  end
end
