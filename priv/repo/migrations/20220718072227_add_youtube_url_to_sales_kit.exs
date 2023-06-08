defmodule BnApis.Repo.Migrations.AddYoutubeUrlToSalesKit do
  use Ecto.Migration

  def change do
    alter table(:stories_sales_kits) do
      add(:youtube_url, :string)
    end
  end
end
