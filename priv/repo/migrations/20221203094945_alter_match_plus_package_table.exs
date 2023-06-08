defmodule BnApis.Repo.Migrations.AlterMatchPlusPackageTable do
  use Ecto.Migration

  def change do
    alter table(:match_plus_packages) do
      # paytm, razorpay, billdesk
      add(:payment_gateway, :string)
      add(:payment_prefs, {:array, :string})
    end
  end
end
