defmodule BnApis.Repo.Migrations.AddMandateCompanyTable do
  use Ecto.Migration

  def up do
    create table(:mandate_companies) do
      add(:mandate_company_name, :string, null: false)

      timestamps()
    end

    create(
      unique_index(
        :mandate_companies,
        ["lower(mandate_company_name)"],
        name: :unique_mandate_company_name_index
      )
    )

    execute(
      "CREATE INDEX pattern_index_mandate_company_name ON mandate_companies (lower(mandate_company_name) varchar_pattern_ops)"
    )
  end

  def down do
    execute("DROP INDEX IF EXISTS pattern_index_mandate_company_name")

    drop_if_exists(
      index(
        :mandate_companies,
        ["lower(mandate_company_name)"],
        name: :unique_mandate_company_name_index
      )
    )

    drop_if_exists(table(:mandate_companies))
  end
end
