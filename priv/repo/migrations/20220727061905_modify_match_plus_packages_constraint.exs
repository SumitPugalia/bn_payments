defmodule BnApis.Repo.Migrations.ModifyMatchPlusPackagesConstraint do
  use Ecto.Migration

  def change do
    drop_if_exists index(:match_plus_packages, [:is_default],
                     name: :mp_packages_unique_index_on_active_default_pkg
                   )

    create(
      unique_index(
        :match_plus_packages,
        [:is_default, :city_id],
        where: "status_id = 1 and is_default = true",
        name: :mp_packages_unique_index_on_active_default_pkg_for_city
      )
    )
  end
end
