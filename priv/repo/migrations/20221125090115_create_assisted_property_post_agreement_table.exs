defmodule BnApis.Repo.Migrations.CreateAssistedPropertyPostAgreementTable do
  use Ecto.Migration

  def up do
    create table(:assisted_property_post_agreements) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :status, :string
      add :notes, :text
      add :validity_in_days, :integer
      add :payment_date, :integer
      add :current_start, :integer
      add :current_end, :integer

      add :resale_property_post_id, references(:resale_property_posts)
      add :building_id, references(:buildings)
      add :assisted_by_id, references(:employees_credentials)
      add :assigned_by_id, references(:employees_credentials)
      add :updated_by_id, references(:employees_credentials)

      timestamps()
    end

    create index(:assisted_property_post_agreements, [:assigned_by_id])
    create index(:assisted_property_post_agreements, [:assisted_by_id])
    create index(:assisted_property_post_agreements, [:uuid])
  end

  def down do
    drop_if_exists index(:assisted_property_post_agreements, [:assigned_by_id])
    drop_if_exists index(:assisted_property_post_agreements, [:assisted_by_id])
    drop_if_exists index(:assisted_property_post_agreements, [:uuid])

    drop table(:assisted_property_post_agreements)
  end
end
