defmodule BnApis.Homeloan.BankCodes do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Homeloan.Bank
  alias BnApis.Homeloan.BankCodes
  alias BnApis.Helpers.ApplicationHelper

  schema "bank_bn_codes" do
    # type of loan
    field(:product_type, :string)
    field(:proof_doc_url, :string)
    field(:bn_code, :string)

    belongs_to :bank, Bank
    timestamps()
  end

  @required [:bank_id, :bn_code, :product_type]
  @optional [:proof_doc_url]

  @doc false
  def changeset(bank_code, attrs) do
    bank_code
    |> cast(attrs, @optional ++ @required)
    |> validate_required(@required)
    |> foreign_key_constraint(:bank_id)
  end

  def add_bn_codes(bn_codes, bank_id) do
    Enum.map(bn_codes, fn {prod_type, values} ->
      BankCodes.changeset(%BankCodes{}, %{
        product_type: prod_type,
        proof_doc_url: values["proof_doc_url"],
        bank_id: bank_id,
        bn_code: values["bn_code"]
      })
      |> Repo.insert()
    end)
  end

  def update_bank_codes(bn_codes, bank_id) do
    Enum.map(bn_codes, fn {prod_type, values} ->
      bank_code = Repo.get_by(BankCodes, bank_id: bank_id, product_type: prod_type)

      case bank_code do
        nil ->
          BankCodes.changeset(%BankCodes{}, %{
            proof_doc_url: values["proof_doc_url"],
            bn_code: values["bn_code"],
            product_type: prod_type,
            bank_id: bank_id
          })
          |> Repo.insert()

        bank_code ->
          BankCodes.changeset(bank_code, %{
            proof_doc_url: values["proof_doc_url"],
            bn_code: values["bn_code"]
          })
          |> Repo.update()
      end
    end)
  end

  def create_bank_code_response(bank) do
    bank_result = %{
      "bank_name" => bank.name,
      "bank_id" => bank.id,
      "bank_logo_url" => bank.logo_url
    }

    bn_codes =
      BankCodes
      |> where([c], c.bank_id == ^bank.id)
      |> Repo.all()
      |> Enum.reduce(%{}, fn bank_code, acc ->
        Map.put(acc, "#{bank_code.product_type}", %{
          "bn_code" => bank_code.bn_code,
          "proof_doc_url" => bank_code.proof_doc_url,
          "proof_doc_prefix" => ApplicationHelper.get_imgix_domain()
        })
      end)

    Map.put(bank_result, "bn_codes", bn_codes)
  end
end
