defmodule Mix.Tasks.UpdateInvoiceStatus do
  use Mix.Task

  alias BnApis.Repo
  alias BnApis.Stories.Schema.Invoice

  @path ["invoice_correction_data.csv"]

  @shortdoc "Update invoice status"
  def run(_) do
    Mix.Task.run("app.start", [])

    IO.puts("STARTING THE UPDATE TASK")

    @path
    |> Enum.each(&update/1)

    IO.puts("UPDATE TASK COMPLETE")
  end

  def update(path) do
    File.stream!("#{File.cwd!()}/priv/data/#{path}")
    |> CSV.decode(strip_fields: true, headers: true)
    |> Enum.each(fn x -> update_status(x) end)
  end

  def update_status({:error, data}) do
    IO.inspect("========== Error: ============")
    IO.inspect(data)
    nil
  end

  def update_status({:ok, data}) do
    # Extract data from CSV
    invoice_id = data["Invoice Id"] |> parse_to_integer()
    current_status = data["Current Status"] |> parse_string()
    revised_status = data["Revised Status"] |> parse_string()

    invoice = get_invoice_by_id(invoice_id)

    case invoice do
      nil ->
        IO.inspect("============== Not Found:  =============")
        IO.inspect("Invoice with invoice_id: #{invoice_id} not found.")

      invoice ->
        update_invoice_status(invoice, revised_status)
        |> case do
          {:ok, _invoice} ->
            IO.inspect("Invoice with invoice_id #{invoice_id} successfully updated with status: #{revised_status}")

          {:error, error} ->
            IO.inspect("============== Error:  =============")
            IO.inspect("Issue while updating invoice with invoice_id: #{invoice_id}, from #{current_status} to #{revised_status} status.")
            IO.inspect(error)
        end
    end
  end

  defp parse_to_integer(nil), do: nil
  defp parse_to_integer(""), do: nil
  defp parse_to_integer(id), do: id |> String.trim() |> String.to_integer()

  defp parse_string(nil), do: nil
  defp parse_string(string), do: string |> String.downcase() |> String.trim()

  defp get_invoice_by_id(nil), do: nil
  defp get_invoice_by_id(invoice_id), do: Invoice |> Repo.get_by(id: invoice_id)

  defp update_invoice_status(invoice, status) do
    invoice
    |> Invoice.changeset(%{status: status})
    |> Repo.update()
  end
end
