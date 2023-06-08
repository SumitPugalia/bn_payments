defmodule BnApis.Repo.Migrations.CreateBucketsTable do
  use Ecto.Migration

  def up do
    create table(:buckets) do
      add(:name, :string, null: false)
      add(:number_of_matching_properties, :integer, null: true, default: 0)
      add(:last_seen_at, :naive_datetime, null: true)
      add(:expires_at, :naive_datetime, null: false)
      add(:filters, :map, default: %{})
      add(:broker_id, references(:brokers, on_delete: :nothing))
      add(:archived, :boolean, default: false, null: false)
      add(:archive_at, :naive_datetime, null: true)
      add(:archived_reason_id, references(:reasons, on_delete: :nothing), null: true)

      timestamps()
    end
  end

  def down do
    drop_if_exists table("buckets")
  end
end
