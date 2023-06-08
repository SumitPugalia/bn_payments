defmodule BnApis.Repo.Migrations.CreateDeveloperPocCredentials do
  use Ecto.Migration

  def change do
    create table(:developer_poc_credentials) do
      add(:uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false)
      add(:name, :string)
      add(:phone_number, :string)
      add(:active, :boolean, default: false, null: false)
      add(:last_active_at, :naive_datetime)
      add(:profile_pic_url, :string)
      timestamps()
    end

    create(unique_index(:developer_poc_credentials, [:phone_number]))
  end
end
