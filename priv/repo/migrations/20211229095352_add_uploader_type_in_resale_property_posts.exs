defmodule BnApis.Repo.Migrations.AddUploaderTypeInResalePropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:resale_property_posts) do
      add(:uploader_type, :string)
    end
  end
end
