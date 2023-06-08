defmodule BnApis.Repo.Migrations.AddIsOtpVerifiedInRawPosts do
  use Ecto.Migration

  def change do
    alter table(:raw_rental_property_posts) do
      add :is_otp_verified, :boolean, default: false
    end

    alter table(:raw_resale_property_posts) do
      add :is_otp_verified, :boolean, default: false
    end
  end
end
