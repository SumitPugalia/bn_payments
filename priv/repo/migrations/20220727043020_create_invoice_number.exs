defmodule BnApis.Repo.Migrations.CreateInvoiceNumber do
  use Ecto.Migration

  def change do
    create table(:invoice_numbers) do
      add(:invoice_number, :string, null: false)

      add(:city_id, references(:cities))
      add(:city_code, :string, null: false)

      add(:invoice_type, :string, null: false)
      add(:invoice_reference_id, :integer, null: false)

      add(:year, :integer, null: false)
      add(:month, :integer, null: false)
      add(:sequence, :integer, null: false)

      timestamps()
    end

    create unique_index(:invoice_numbers, [:invoice_number])

    create(
      unique_index(
        :invoice_numbers,
        [:sequence, :month, :year, :invoice_type, :city_code],
        name: :invoice_number_sequence_index
      )
    )

    create(
      unique_index(
        :invoice_numbers,
        [:invoice_reference_id, :invoice_type],
        name: :invoice_reference_id_index
      )
    )
  end
end
