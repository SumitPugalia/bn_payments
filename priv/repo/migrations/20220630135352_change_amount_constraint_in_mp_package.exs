defmodule BnApis.Repo.Migrations.ChangeAmountConstraintInMpPackage do
  use Ecto.Migration

  def up do
    drop_if_exists index(:match_plus_packages, [:amount_in_rupees],
                     where: "status_id = 1",
                     name: :match_plus_packages_amount_unique_constraint_on_status_id_active
                   )

    create unique_index(:match_plus_packages, [:amount_in_rupees, :city_id],
             where: "status_id = 1",
             name: :mp_packages_amount_city_unique_constraint_on_status_id_active
           )
  end

  def down do
    drop_if_exists index(:match_plus_packages, [:amount_in_rupees, :city_id],
                     where: "status_id = 1",
                     name: :mp_packages_amount_city_unique_constraint_on_status_id_active
                   )

    create unique_index(:match_plus_packages, [:amount_in_rupees],
             where: "status_id = 1",
             name: :match_plus_packages_amount_unique_constraint_on_status_id_active
           )
  end
end
