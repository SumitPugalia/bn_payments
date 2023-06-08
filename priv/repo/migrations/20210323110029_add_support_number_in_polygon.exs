defmodule BnApis.Repo.Migrations.AddSupportNumberInPolygon do
  use Ecto.Migration

  def change do
    alter table(:polygons) do
      add :support_number, :string, default: "+918097404157", null: false
    end
  end
end
