defmodule BnApis.Repo.Migrations.AddAmountUniquenessInMatchPlusPackages do
  use Ecto.Migration

  def change do
    create unique_index(:match_plus_packages, [:amount_in_rupees],
             where: "status_id = 1",
             name: :match_plus_packages_amount_unique_constraint_on_status_id_active
           )
  end
end
