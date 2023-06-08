defmodule BnApis.Repo.Migrations.AddShippingFieldsToLegalEntity do
  use Ecto.Migration

  def change do
    alter table(:legal_entities) do
      add(:shipping_address, :string)
      add(:ship_to_name, :string)
    end
  end
end
