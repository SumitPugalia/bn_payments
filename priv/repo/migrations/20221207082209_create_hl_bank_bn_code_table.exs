defmodule BnApis.Repo.Migrations.CreateHlBankBnCodeTable do
  use Ecto.Migration

  def change do
    create table(:bank_bn_codes) do
      add(:product_type, :string)
      add(:proof_doc_url, :string)
      add(:bn_code, :string)
      add(:commission_percent, :float)

      add(:bank_id, references(:homeloan_banks), null: false)
      timestamps()
    end
  end
end
