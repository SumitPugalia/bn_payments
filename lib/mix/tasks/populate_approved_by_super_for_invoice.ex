defmodule Mix.Tasks.PopulateApprovedBySuperForInvoice do
  use Mix.Task
  import Ecto.Query

  alias BnApis.Accounts.Credential
  alias BnApis.Stories.Schema.Invoice
  alias BnApis.Log
  alias BnApis.Repo

  @shortdoc "Populate Approved By Super UserId in Invoice"

  def run(_) do
    Mix.Task.run("app.start", [])

    get_invoices()
    |> Enum.map(fn i ->
      invoice = Repo.get_by(Invoice, id: i.invoice_id)

      case invoice |> Invoice.changeset(%{approved_by_super_id: i.user_id}) |> Repo.update() do
        {:ok, invoice} -> IO.puts("Successfully updated for invoice_id: #{i.invoice_id}")
        {:error, changeset} -> IO.puts(changeset)
      end
    end)
  end

  def get_invoices() do
    Log
    |> join(:inner, [l], i in Invoice, on: i.id == l.entity_id and l.entity_type == "invoices")
    |> where([l, i], fragment("(changes ->> 'status') = 'approved_by_finance'") and l.user_type == "Employee")
    |> where([l, i], is_nil(i.approved_by_super_id))
    |> order_by([l, i], asc: l.inserted_at)
    |> select([l, i], %{
      invoice_id: i.id,
      user_id: l.user_id
    })
    |> Repo.all()
  end
end
