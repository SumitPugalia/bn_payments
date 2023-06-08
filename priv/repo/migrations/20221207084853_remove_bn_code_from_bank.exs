defmodule BnApis.Repo.Migrations.RemoveBnCodeFromBank do
  use Ecto.Migration

  def change do
    alter table(:homeloan_banks) do
      remove :bn_code
    end
  end
end
