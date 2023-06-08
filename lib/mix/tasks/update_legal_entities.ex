defmodule Mix.Tasks.UpdateLegalEntities do
  use Mix.Task
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Stories.LegalEntity
  alias BnApis.Helpers.{AuditedRepo, Utils}

  @shortdoc "Update Legal Entity GST Params in DB"
  def run(_) do
    Mix.Task.run("app.start", [])

    IO.puts("STARTING TO UPDATE LEGAL ENTITY GST PARAMS")

    update_legal_entities()

    IO.puts("LEGAL ENTITY GST PARAMS UPDATE COMPLETED")
  end

  def update_legal_entities() do
    user_map = Utils.get_employee_user_map(%{"phone_number" => "cron", "country_code" => "+91"})

    stream =
      LegalEntity
      |> where([le], fragment("lower(?)", le.gst) == "unregistered")
      |> Repo.stream()
      |> Stream.each(fn le -> update_gst_params(le, user_map) end)

    Repo.transaction(fn -> Stream.run(stream) end)

    stream =
      LegalEntity
      |> where([le], is_nil(le.state_code))
      |> Repo.stream()
      |> Stream.each(fn le -> update_state_code(le, user_map) end)

    Repo.transaction(fn -> Stream.run(stream) end)
  end

  def update_gst_params(le, user_map) do
    try do
      case LegalEntity.changeset(le, %{"gst" => nil, "is_gst_required" => false}) |> AuditedRepo.update(user_map) do
        {:ok, _data} -> :ok
        {:error, reason} -> IO.inspect({:error, reason})
      end
    rescue
      err -> IO.puts("Error raised while updating LegalEntity with id: #{le.id}. Error: #{err}")
    end
  end

  def update_state_code(le, user_map) do
    state_code = get_state_code(le.place_of_supply)

    try do
      case LegalEntity.changeset(le, %{"state_code" => state_code}) |> AuditedRepo.update(user_map) do
        {:ok, _data} -> :ok
        {:error, reason} -> IO.inspect({:error, reason}, label: "ID: #{le.id}")
      end
    rescue
      err -> IO.puts("Error raised while updating LegalEntity with id: #{le.id}. Error: #{err}")
    end
  end

  defp get_state_code(state) do
    case String.downcase(state) do
      "haryana" -> 6
      "delhi" -> 7
      "karnataka" -> 29
      "maharashtra" -> 27
      "rajasthan" -> 8
      "tamil nadu" -> 33
      _ -> nil
    end
  end
end
