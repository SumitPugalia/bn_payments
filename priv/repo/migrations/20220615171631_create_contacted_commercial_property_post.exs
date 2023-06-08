defmodule BnApis.Repo.Migrations.CreateContactedCommercialPropertyPost do
  use Ecto.Migration

  def change do
    create table(:contacted_commercial_property_posts) do
      add :user_id, references(:brokers)
      add :commercial_property_post_id, references(:commercial_property_posts), null: false
      add :call_time, :naive_datetime
      timestamps()
    end
  end
end
