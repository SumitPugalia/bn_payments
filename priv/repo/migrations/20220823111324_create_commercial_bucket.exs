defmodule BnApis.Repo.Migrations.CreateCommercialBucket do
  use Ecto.Migration

  def change do
    create table(:commercial_bucket) do
      add(:uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false)
      add(:token_id, :uuid, default: fragment("uuid_generate_v1mc()"), null: false)
      add(:name, :string)
      add(:option_posts, {:array, :map}, default: [])
      add(:shortlisted_posts, {:array, :map}, default: [])
      add(:negotiation_posts, {:array, :map}, default: [])
      add(:finalized_posts, {:array, :map}, default: [])
      add(:visit_posts, {:array, :map}, default: [])
      add(:active, :boolean, default: true)
      add(:broker_id, references(:brokers))
      timestamps()
    end
  end
end
