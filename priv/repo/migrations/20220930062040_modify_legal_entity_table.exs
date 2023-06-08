defmodule BnApis.Repo.Migrations.ModifyLegalEntityTable do
  use Ecto.Migration

  def change do
    alter table(:legal_entities) do
      add(:is_gst_required, :boolean, default: true)
    end
  end
end
