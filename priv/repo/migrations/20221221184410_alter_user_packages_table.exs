defmodule BnApis.Repo.Migrations.AlterUserPackagesTable do
  use Ecto.Migration

  def up do
    alter table(:user_packages) do
      add(:type, :string)
      add(:auto_renew, :boolean)
    end
  end

  def down do
    alter table(:user_packages) do
      remove(:type, :string)
      remove(:auto_renew, :boolean)
    end
  end
end
