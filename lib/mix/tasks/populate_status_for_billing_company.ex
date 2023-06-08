defmodule Mix.Tasks.PopulateStatusForBillingCompany do
  use Mix.Task
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Organizations.{Broker, BillingCompany}
  alias BnApis.Stories.Schema.Invoice

  @shortdoc "populate status for billing companies created by Real Estate Brokers"
  def run(_) do
    Mix.Task.run("app.start", [])
    populate_status_for_billing_companies()
  end

  def populate_status_for_billing_companies() do
    IO.puts("STARTED THE TASK - populate status for billing companies created by Real Estate Brokers")

    fetch_billing_companies_to_be_updated()
    |> Enum.each(fn billing_company ->
      status = generate_status_by_broker_invoices(billing_company.broker_id)
      update_status_for_billing_company(billing_company, status)
    end)

    IO.puts("FINISHED THE TASK - populate status for billing companies created by Real Estate Brokers")
  end

  defp fetch_billing_companies_to_be_updated() do
    BillingCompany
    |> join(:left, [bc], br in assoc(bc, :broker))
    |> where([bc, br], br.role_type_id == ^Broker.real_estate_broker()["id"] and is_nil(bc.status))
    |> Repo.all()
  end

  defp get_paid_or_approved_invoices_count(broker_id) do
    Invoice
    |> where([inv], inv.broker_id == ^broker_id)
    |> where([inv], inv.status == "approved" or inv.status == "paid")
    |> Repo.all()
  end

  defp generate_status_by_broker_invoices(broker_id) do
    paid_or_approved_invoices_count = get_paid_or_approved_invoices_count(broker_id)
    if length(paid_or_approved_invoices_count) > 0, do: :approved, else: :approval_pending
  end

  defp update_status_for_billing_company(billing_company, status) do
    billing_company
    |> BillingCompany.changeset(%{status: status})
    |> case do
      {:ok, changeset} ->
        Repo.update(changeset)

      {:error, error} ->
        IO.inspect("============== Error:  =============")
        IO.inspect("Issue while updating billing company with ID: #{billing_company.id} with status: #{status}")
        IO.inspect(error)
    end
  end
end
