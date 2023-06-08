defmodule Mix.Tasks.PopulateLegalEntityData do
  use Mix.Task
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Stories.LegalEntity
  alias BnApis.Helpers.{AuditedRepo, Utils}

  @path ["legal_entity_data_06102022.csv"]

  @shortdoc "Populate Legal Entity Data in DB"
  def run(_) do
    Mix.Task.run("app.start", [])

    IO.puts("STARTING TO ADD LEGAL ENTITY DATA")

    @path
    |> Enum.each(&populate/1)

    IO.puts("LEGAL ENTITY DATA POPULATION COMPLETED")
  end

  def populate(path) do
    File.stream!("#{File.cwd!()}/priv/data/#{path}")
    |> CSV.decode(strip_fields: true, headers: true)
    |> Enum.each(fn x -> populate_legal_entity(x) end)
  end

  def populate_legal_entity({:error, data}) do
    IO.inspect("========== Error: ============")
    IO.inspect(data)
    nil
  end

  def populate_legal_entity({:ok, data}) do
    attrs = %{
      "legal_entity_name" => String.trim(data["legal_entity_name"]),
      "billing_address" => String.trim(data["billing_address"]),
      "shipping_address" => String.trim(data["shipping_address"]),
      "gst" => String.trim(data["gst"]),
      "pan" => String.trim(data["pan"]),
      "sac" => String.trim(data["sac"]),
      "place_of_supply" => String.trim(data["place_of_supply"]),
      "is_gst_required" => Utils.parse_boolean_param(data["is_gst_required"], true),
      "state_code" => Utils.parse_to_integer(data["state_code"]),
      "ship_to_name" => String.trim(data["ship_to_name"])
    }

    attrs = refine_attrs(attrs)
    user_map = Utils.get_employee_user_map(%{"phone_number" => "cron", "country_code" => "+91"})

    legal_entity_exists? = not is_nil(get_legal_entity_from_repo_by_pan(attrs["pan"]))

    case legal_entity_exists? do
      true ->
        IO.inspect("Legal Entity with Name: #{attrs["legal_entity_name"]} and PAN: #{attrs["pan"]} already exists")

      false ->
        with {:ok, _legal_entity} <- create_legal_entity(attrs, user_map) do
          IO.inspect("Record with Name: #{attrs["legal_entity_name"]} and PAN: #{attrs["pan"]} added")
        else
          {:error, error} ->
            IO.inspect("============== Error:  =============")
            IO.inspect("Issue while adding record with Name: #{attrs["legal_entity_name"]} and PAN: #{attrs["pan"]}")
            IO.inspect(error)
            IO.inspect(attrs)
        end
    end
  end

  defp parse_for_nil(_field = "", key), do: "EMPTY_" <> key

  defp parse_for_nil(field, _key), do: field

  defp refine_attrs(attrs) do
    legal_entity_name = Map.get(attrs, "legal_entity_name", "") |> parse_for_nil("legal_entity_name")
    pan = Map.get(attrs, "pan", "") |> parse_for_nil("pan")
    place_of_supply = Map.get(attrs, "place_of_supply", "") |> parse_for_nil("place_of_supply")

    Map.merge(attrs, %{
      "legal_entity_name" => legal_entity_name,
      "pan" => pan,
      "place_of_supply" => place_of_supply
    })
  end

  defp get_legal_entity_from_repo_by_pan(pan) do
    LegalEntity
    |> where([le], fragment("lower(?) = lower(?)", le.pan, ^pan))
    |> limit(1)
    |> Repo.one()
  end

  defp create_legal_entity(attrs, user_map) do
    LegalEntity.changeset(%LegalEntity{}, attrs) |> AuditedRepo.insert(user_map)
  end
end
