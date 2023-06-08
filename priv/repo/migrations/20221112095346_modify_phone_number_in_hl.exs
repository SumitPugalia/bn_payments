defmodule BnApis.Repo.Migrations.ModifyPhoneNumberInHl do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      modify(:phone_number, :string, null: true, from: :string)
    end
  end
end
