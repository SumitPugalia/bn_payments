defmodule BnApis.Repo.Migrations.AddReasonKeyToReasonTypes do
  use Ecto.Migration

  def change do
    alter table(:reasons_types) do
      add :reason_key, :string
    end
  end
end
