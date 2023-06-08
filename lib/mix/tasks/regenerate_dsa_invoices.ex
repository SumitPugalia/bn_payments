defmodule Mix.Tasks.RegenerateDsaInvoices do
  use Mix.Task
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Stories.Schema.Invoice
  alias BnApis.Stories.Invoice, as: Invoices
  alias BnApis.Homeloan.LoanDisbursement

  @shortdoc "Regenerate dsa invoices"
  def run(_) do
    Mix.Task.run("app.start", [])
    regenerate_dsa_invoices()
  end

  defp regenerate_dsa_invoices() do
    Invoice
    |> join(:inner, [i], l in LoanDisbursement, on: l.id == i.entity_id and i.entity_type == :loan_disbursements)
    |> where([i, l], i.type == "dsa" and not is_nil(i.invoice_pdf_url) and not is_nil(l.commission_percentage))
    |> where([i, l], l.active == true and not is_nil(l.loan_file_id))
    |> Repo.all()
    |> Enum.each(fn invoice ->
      try do
        IO.inspect("Starting to generate invoice for id: #{invoice.id}")

        invoice = Invoices.get_invoice_by_uuid(invoice.uuid)
        invoice = Invoices.preload_invoice_entity(invoice)
        loan_commission_percent = Invoices.float_round(invoice.loan_disbursements.commission_percentage)

        case Invoices.generate_dsa_homeloan_invoice(invoice, %{user_id: 497, user_type: "Employee"}, %{"loan_commission" => loan_commission_percent}) do
          {:ok, _} -> IO.inspect("Successfully generated invoice for id - #{invoice.id}")
          {:error, error} -> IO.inspect(error)
        end
      rescue
        err -> IO.inspect("Not able to generate invoice for id: #{invoice.id}, error - #{Exception.message(err)}")
      end
    end)
  end
end
