defmodule BnApis.Repo.Migrations.CreateAssistedPropertyPostAgreementLogTable do
  use Ecto.Migration

  def change do
    create table(:assisted_property_post_agreement_log) do
      add :status, :string
      add :notes, :text
      add :updated_by_id, references(:employees_credentials)
      add :agreement_id, references(:assisted_property_post_agreements)

      timestamps()
    end
  end
end
