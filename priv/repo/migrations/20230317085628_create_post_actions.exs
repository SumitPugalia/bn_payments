defmodule BnApis.Repo.Migrations.CreatePostActions do
  use Ecto.Migration

  def change do
    create table(:broker_post_actions) do
      add(:post_type, :string, null: false)
      add(:post_uuid, :string, null: false)
      add :user_id, references(:brokers, on_delete: :nothing)
      add :action, :string
      timestamps()
    end

    create index(:broker_post_actions, [:action, :post_type, :post_uuid])
    create index(:broker_post_actions, [:action, :user_id])
  end
end
