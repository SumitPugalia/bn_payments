defmodule BnApis.Repo.Migrations.AlterRawPosts do
  use Ecto.Migration

  def change do
    rename table(:raw_resale_property_posts), :employee_credentials_id,
      to: :updated_by_employee_credential_id

    rename table(:raw_rental_property_posts), :employee_credentials_id,
      to: :updated_by_employee_credential_id

    rename table(:post_leads), :created_by_employee_id, to: :created_by_employee_credential_id
  end
end
