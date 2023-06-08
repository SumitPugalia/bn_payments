defmodule BnApis.Repo.Migrations.RmUniquenessInMatchPlusPackages do
  use Ecto.Migration

  def change do
    drop_if_exists index(:match_plus_packages, [:amount_in_rupees, :city_id],
                     where: "status_id = 1",
                     name: :mp_packages_amount_city_unique_constraint_on_status_id_active
                   )

    drop_if_exists index(
                     :match_plus_packages,
                     [:is_default, :city_id],
                     where: "status_id = 1 and is_default = true",
                     name: :mp_packages_unique_index_on_active_default_pkg_for_city
                   )
  end
end
