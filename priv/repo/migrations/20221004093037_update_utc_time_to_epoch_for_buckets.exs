defmodule BnApis.Repo.Migrations.UpdateUtcTimeToEpochForBuckets do
  use Ecto.Migration

  def up do
    alter table(:buckets) do
      add(:last_seen_at_u, :integer, null: true)
      add(:expires_at_u, :integer, null: false, default: fragment("extract(epoch from now())"))
      add(:archive_at_u, :integer, null: true)
    end

    execute(
      "Update buckets SET last_seen_at_u = extract(epoch from last_seen_at), expires_at_u = extract(epoch from expires_at), archive_at_u = extract(epoch from archive_at);"
    )

    alter table(:buckets) do
      remove(:last_seen_at)
      remove(:expires_at)
      remove(:archive_at)
    end

    rename table(:buckets), :last_seen_at_u, to: :last_seen_at
    rename table(:buckets), :expires_at_u, to: :expires_at
    rename table(:buckets), :archive_at_u, to: :archive_at
  end

  def down do
    alter table(:buckets) do
      add(:last_seen_at_u, :naive_datetime, null: true)
      add(:expires_at_u, :naive_datetime, null: false, default: fragment("now()"))
      add(:archive_at_u, :naive_datetime, null: true)
    end

    execute(
      "Update buckets SET last_seen_at_u = to_timestamp(last_seen_at), expires_at_u = to_timestamp(expires_at), archive_at_u = to_timestamp(archive_at);"
    )

    alter table(:buckets) do
      remove(:last_seen_at)
      remove(:expires_at)
      remove(:archive_at)
    end

    rename table(:buckets), :last_seen_at_u, to: :last_seen_at
    rename table(:buckets), :expires_at_u, to: :expires_at
    rename table(:buckets), :archive_at_u, to: :archive_at
  end
end
