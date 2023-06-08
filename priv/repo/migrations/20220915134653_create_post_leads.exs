defmodule BnApis.Repo.Migrations.CreatePostLeads do
  use Ecto.Migration

  def change do
    create table(:post_leads) do
      add(:post_type, :string, null: false)
      add(:post_uuid, :string, null: false)
      add(:source, :string, null: false)
      add(:country_code, :string, null: false)
      add(:phone_number, :string, null: false)
      add(:lead_status, :string)
      add(:slash_reference_id, :string)
      add(:pushed_to_slash, :boolean, default: false)
      add(:token_id, :string)
      add(:notes, :string)
      add(:created_by_employee_id, references(:employees_credentials), null: false)
      timestamps()
    end
  end
end
