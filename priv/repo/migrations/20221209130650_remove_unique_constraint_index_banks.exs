defmodule BnApis.Repo.Migrations.RemoveUniqueConstraintIndexBanks do
  use Ecto.Migration

  def change do
    drop_if_exists(
      unique_index(:homeloan_banks, ["lower(name)"], name: :uniq_homeloan_banks_name_idx)
    )

    create unique_index(:homeloan_banks, ["lower(name)"],
             where: "active = true",
             name: :uniq_homeloan_banks_name_active_idx
           )
  end
end
