defmodule Mix.Tasks.PopulateTotalPayableAmountInInvoices do
  use Mix.Task
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Stories.Schema.Invoice
  alias BnApis.Stories.Invoice, as: Invoices
  alias BnApis.Homeloan.LoanDisbursement
  alias BnApis.Helpers.Utils

  @cgst 0.09
  @sgst 0.09
  @valid_cities_in_maharastra [1, 2]

  @shortdoc "Regenerate dsa invoices"
  def run(_) do
    Mix.Task.run("app.start", [])
    populate_net_payable_amount_in_invoice()
  end

  defp populate_net_payable_amount_in_invoice() do
    invoices = Mix.Tasks.PopulateTotalPayableAmountInInvoices.get_all_invoices()
    invoices |> Enum.each(fn invoice ->
      try do
        IO.inspect("Starting to generate invoice for id: #{invoice.id}")

        invoice = Invoices.get_invoice_by_uuid(invoice.uuid)
        invoice = Invoices.preload_invoice_entity(invoice)
        loan_commission_percent = Invoices.float_round(invoice.loan_disbursements.commission_percentage)

        case add_amount_in_each_invoice(invoice, %{user_id: 289, user_type: "Employee"}, %{"loan_commission" => loan_commission_percent}) do
          {:ok, updated_invoice} -> IO.inspect("successfully data updated: #{invoice.id}, is_tds_valid: #{updated_invoice.is_tds_valid}, total_payable_amount: #{updated_invoice.total_payable_amount}, tds_percentage: #{updated_invoice.tds_percentage}")
          {:error, error} -> IO.inspect(error)
        end
      rescue
        err -> IO.inspect("Not able to generate invoice for id: #{invoice.id}, error - #{Exception.message(err)}")
      end
    end)
  end

  def get_all_invoices() do
    Invoice
    |> join(:inner, [i], l in LoanDisbursement, on: l.invoice_id == i.id and l.active == true)
    |> where([i, l], i.type == "dsa" and is_nil(i.total_payable_amount) and is_nil(i.tds_percentage) and not is_nil(l.commission_percentage))
    |> Repo.all()
  end

  def add_amount_in_each_invoice(invoice, user_map, %{"loan_commission" => loan_commission}) do
    loan_commission = if is_binary(loan_commission), do: loan_commission |> String.to_float(), else: loan_commission
    is_tds_valid = Utils.parse_boolean_param(invoice.is_tds_valid, false)
    tds = if is_tds_valid == true, do: 0.20, else: 0.05
    igst = 0.18
    in_maharastra = invoice.broker.operating_city in @valid_cities_in_maharastra
    invoice_amount = LoanDisbursement.get_dsa_commission_amount(invoice.loan_disbursements, loan_commission)
    has_gst = not is_nil(invoice.billing_company.gst)

    multiplier =
      if has_gst do
        if in_maharastra, do: 1 - tds + @cgst + @sgst, else: 1 - tds + igst
      else
        1 - tds
      end

    invoice =
      Map.merge(invoice, %{
        total_invoice_amount: Invoices.float_round(invoice_amount * multiplier),
        net_payable: Invoices.float_round(invoice_amount - invoice_amount * tds)
      })

    with {:ok, updated_invoice} <- Invoices.update_invoice_data(%{}, invoice, user_map) do
      {:ok, updated_invoice}
    else
      nil -> {:error, "Something went wrong file generating invoice PDF."}
      {:error, error} -> {:error, error}
    end
  end
end
