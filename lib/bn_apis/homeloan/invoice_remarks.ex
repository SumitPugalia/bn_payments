defmodule BnApis.Homeloan.InvoiceRemarks do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Stories.Schema.Invoice
  alias BnApis.Homeloan.InvoiceRemarks

  schema "invoice_remarks" do
    field(:remark, :string)
    field(:active, :boolean, default: true)

    belongs_to(:invoice, Invoice)
    belongs_to(:employee_credential, EmployeeCredential)

    timestamps()
  end

  @required [:remark, :invoice_id, :active]
  @optional [:employee_credential_id]

  @doc false
  def changeset(remark, attrs) do
    remark
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:invoice_id)
    |> foreign_key_constraint(:employee_credential_id)
  end

  def add_remark(remark, invoice_id, employee_credential_id) do
    changeset =
      InvoiceRemarks.changeset(%InvoiceRemarks{}, %{
        remark: remark,
        invoice_id: invoice_id,
        employee_credential_id: employee_credential_id,
        active: true
      })

    Repo.insert(changeset)
  end

  def delete_remark(invoice_remark_id) do
    invoice_remark = Repo.get_by(InvoiceRemarks, id: invoice_remark_id, active: true)

    case invoice_remark do
      nil -> {:error, :not_found}
      invoice_remark -> InvoiceRemarks.changeset(invoice_remark, %{active: false}) |> Repo.update()
    end
  end

  def edit_remark(remark, invoice_remark_id, employee_credential_id) do
    invoice_remark = Repo.get_by(InvoiceRemarks, id: invoice_remark_id, active: true)

    case invoice_remark do
      nil ->
        {:error, :not_found}

      invoice_remark ->
        InvoiceRemarks.changeset(invoice_remark, %{remark: remark, employee_credential_id: employee_credential_id})
        |> Repo.update()
    end
  end

  def get_invoice_remarks(invoice_id) do
    InvoiceRemarks
    |> where([ir], ir.invoice_id == ^invoice_id and ir.active == true)
    |> select([ir], %{
      remark: ir.remark,
      created_at: ir.inserted_at,
      id: ir.id
    })
    |> Repo.all()
  end
end
