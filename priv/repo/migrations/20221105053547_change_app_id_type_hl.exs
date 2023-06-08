defmodule BnApis.Repo.Migrations.ChangeAppIdTypeHl do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      add(:sanctioned_doc_url, :string)
      modify(:application_id, :string)
    end
  end
end
