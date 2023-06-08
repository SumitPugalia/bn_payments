defmodule BnApis.Repo.Migrations.AddApnsIdSourceInCredentials do
  use Ecto.Migration

  def change do
    alter table(:credentials) do
      add(:apns_id, :string)
      add(:source, :string)
    end
  end
end
