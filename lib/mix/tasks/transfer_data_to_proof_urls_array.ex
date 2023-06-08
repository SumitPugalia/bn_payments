defmodule Mix.Tasks.TransferDataToProofUrlsArray do
  use Mix.Task
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Stories.Schema.Invoice

  @shortdoc "Transfer proof_url to proof_url array in invoices"

  def run(_) do
    Mix.Task.run("app.start", [])
    process_data()
  end

  defp process_data() do
    try do
      stream =
        Invoice
        |> where([inv], not is_nil(inv.proof_url))
        |> Repo.stream()
        |> Stream.each(fn x -> transfer_proof_url_data(x, x.proof_url, x.proof_urls) end)

      Repo.transaction(fn -> Stream.run(stream) end)
    rescue
      err -> IO.inspect(err)
    end
  end

  defp transfer_proof_url_data(inv, proof_url, nil), do: update_invoice(inv, [proof_url])

  defp transfer_proof_url_data(inv, proof_url, proof_urls_list) do
    url = Enum.find(proof_urls_list, fn url -> url == proof_url end)

    if is_nil(url) do
      proof_urls_list = proof_urls_list ++ proof_url
      update_invoice(inv, proof_urls_list)
    end
  end

  defp update_invoice(inv, proof_urls_list) do
    case Invoice.changeset(inv, %{proof_urls: proof_urls_list}) |> Repo.update() do
      {:ok, _data} -> :ok
      {:error, reason} -> IO.puts("Error while updating invoice with id: #{inv.id}. Error: #{reason}")
    end
  end
end
