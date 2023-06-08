defmodule BnApis.Repo.Migrations.ModifyFieldTypeInCallDetails do
  use Ecto.Migration

  def change do
    alter table(:call_details) do
      modify :duration, :string
      modify :charge, :string
    end
  end
end
