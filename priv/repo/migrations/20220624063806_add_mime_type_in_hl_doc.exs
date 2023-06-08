defmodule BnApis.Repo.Migrations.AddMimeTypeInHlDoc do
  use Ecto.Migration

  def change do
    alter table(:homeloan_documents) do
      add :mime_type, :string
    end
  end

  def change do
  end
end
