defmodule BnApis.Repo.Migrations.AddUploaderTypeInRentalPropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:rental_property_posts) do
      add(:uploader_type, :string)
      add(:available_from, :naive_datetime)
    end
  end
end
