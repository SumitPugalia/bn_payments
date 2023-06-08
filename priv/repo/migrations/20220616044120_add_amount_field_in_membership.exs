defmodule BnApis.Repo.Migrations.AddAmountFieldInMembership do
  use Ecto.Migration

  def change do
    alter table(:memberships) do
      add(:subscription_amount, :string)
    end
  end
end
