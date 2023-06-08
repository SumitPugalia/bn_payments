defmodule BnApis.Repo.Migrations.AlterContactedCommercialPropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:contacted_commercial_property_posts) do
      remove :user_id
      remove :call_time
      add(:call_time, :integer)
      add :contacted_by_id, references(:credentials)
    end
  end
end
