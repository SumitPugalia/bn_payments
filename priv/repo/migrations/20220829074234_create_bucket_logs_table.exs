defmodule BnApis.Repo.Migrations.CreateBucketLogsTable do
  use Ecto.Migration

  def change do
    create table(:commercial_bucket_logs) do
      add(:opened_at, :integer)
      add(:active, :boolean, default: true)
      add(:broker_id, references(:brokers))
      add(:bucket_id, references(:commercial_bucket))
      timestamps()
    end
  end
end
