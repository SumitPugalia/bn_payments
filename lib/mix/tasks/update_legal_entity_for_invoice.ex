defmodule Mix.Tasks.UpdateLegalEntityForInvoice do
  use Mix.Task

  alias BnApis.Repo
  alias BnApis.Stories.LegalEntity
  alias BnApis.Stories.Schema.Invoice
  alias BnApis.Helpers.{Utils, AuditedRepo}

  @path ["invoice_legal_entity_mapping.csv"]

  @shortdoc "Update legal entity for invoices"
  def run(_) do
    Mix.Task.run("app.start", [])

    IO.puts("STARTING TO UPDATE LEGAL ENTITY FOR INVOICE")

    @path
    |> Enum.each(&populate/1)

    IO.puts("ONE TIMER COMPLETED")
  end

  def populate(path) do
    File.stream!("#{File.cwd!()}/priv/data/#{path}")
    |> CSV.decode(strip_fields: true, headers: true)
    |> Enum.each(fn x -> update_legal_entity_for_invoice(x) end)
  end

  def update_legal_entity_for_invoice({:error, data}) do
    IO.inspect("============== Error: =============")
    IO.inspect(data)
    nil
  end

  def update_legal_entity_for_invoice({:ok, data}) do
    invoice_id = data["Invoice Id"] |> parse_to_integer()
    legal_entity_id = data["legal_entity_id"] |> parse_to_integer()

    invoice = get_invoice_by_id(invoice_id)
    legal_entity = get_legal_entity_by_id(legal_entity_id)

    valid_invoice? = not is_nil(invoice)
    valid_legal_entity? = not is_nil(legal_entity)

    case {valid_invoice?, valid_legal_entity?} do
      {false, _} ->
        IO.inspect("============== Invalid Invoice =============")
        IO.inspect("Invalid invoice_id: #{invoice_id}")

      {_, false} ->
        IO.inspect("============== Invalid Legal Entity =============")
        IO.inspect("Invalid legal_entity_id: #{legal_entity_id}")

      {true, true} ->
        user_map = Utils.get_employee_user_map(%{"phone_number" => "cron", "country_code" => "+91"})

        with {:ok, invoice} <- update_legal_entity_id_for_invoice(invoice, legal_entity.id, user_map) do
          IO.inspect("Legal Entity updated for invoice, invoice_id: #{invoice.id} and legal_entity_id: #{legal_entity.id}")
        else
          {:error, error} ->
            IO.inspect("============== Error:  =============")
            IO.inspect("Issue while updating legal entity for invoice, invoice_id: #{invoice_id} and legal_entity_id: #{legal_entity_id}")
            IO.inspect(error)
        end
    end
  end

  defp parse_to_integer(nil), do: nil
  defp parse_to_integer(""), do: nil
  defp parse_to_integer(id), do: id |> String.trim() |> String.to_integer()

  defp get_invoice_by_id(nil), do: nil
  defp get_invoice_by_id(invoice_id), do: Invoice |> Repo.get_by(id: invoice_id)

  defp get_legal_entity_by_id(nil), do: nil
  defp get_legal_entity_by_id(legal_entity_id), do: LegalEntity |> Repo.get_by(id: legal_entity_id)

  defp update_legal_entity_id_for_invoice(invoice, legal_entity_id, user_map) do
    invoice
    |> Invoice.changeset(%{
      legal_entity_id: legal_entity_id
    })
    |> AuditedRepo.update(user_map)
  end
end
