defmodule BnApis.Repo.Migrations.AddOfferDetailsInMatchPlusPackages do
  use Ecto.Migration

  def change do
    alter table(:match_plus_packages) do
      add :original_amount_in_rupees, :integer, null: false
      add :offer_title, :string
      add :offer_text, :string
    end
  end
end
