defmodule BnApis.Stories.LegalEntity do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Helpers.AuditedRepo
  alias BnApis.Stories.LegalEntity
  alias BnApis.Stories.Story
  alias BnApis.Stories.StoryLegalEntityMapping
  alias BnApis.Schemas.LegalEntityPoc
  alias BnApis.Stories.LegalEntityPocMapping

  schema "legal_entities" do
    field(:uuid, Ecto.UUID, read_after_writes: true)
    field(:legal_entity_name, :string)
    field(:billing_address, :string)
    field(:gst, :string)
    field(:pan, :string)
    field(:sac, :integer)
    field(:state_code, :integer)
    field(:place_of_supply, :string)
    field(:shipping_address, :string)
    field(:ship_to_name, :string)
    field(:is_gst_required, :boolean, default: true)

    many_to_many(:stories, Story, join_through: "story_legal_entity_mappings", on_replace: :delete)

    many_to_many(:legal_entity_pocs, LegalEntityPoc, join_through: "legal_entity_poc_mappings", on_replace: :delete)

    timestamps()
  end

  @seed_data [
    %{
      legal_entity_name: "4B NETWORKS PRIVATE LIMITED",
      billing_address: "Ground Floor, A UNIT OF FLEUR HOTELS PVT LTD, LEMON TREE PREMIER HOTEL, Behind RBL Bank Marol Andheri East, Mumbai, Mumbai Suburban, Maharashtra, 400059",
      shipping_address: "Ground Floor, A UNIT OF FLEUR HOTELS PVT LTD, LEMON TREE PREMIER HOTEL, Behind RBL Bank Marol Andheri East, Mumbai, Mumbai Suburban, Maharashtra, 400059",
      gst: "27AABCZ6271C1ZB",
      pan: "AABCZ6271C",
      state_code: 27,
      place_of_supply: "MAHARASHTRA",
      ship_to_name: "4B NETWORKS PRIVATE LIMITED"
    }
  ]

  @fields [
    :uuid,
    :legal_entity_name,
    :billing_address,
    :gst,
    :pan,
    :sac,
    :state_code,
    :place_of_supply,
    :shipping_address,
    :ship_to_name,
    :is_gst_required
  ]

  @gst_code_to_place_of_supply %{
    1 => %{name: "JAMMU AND KASHMIR", gst: 01},
    2 => %{name: "HIMACHAL PRADESH", gst: 02},
    3 => %{name: "PUNJAB", gst: 03},
    4 => %{name: "CHANDIGARH", gst: 04},
    5 => %{name: "UTTARAKHAND", gst: 05},
    6 => %{name: "HARYANA", gst: 06},
    7 => %{name: "DELHI", gst: 07},
    8 => %{name: "RAJASTHAN", gst: 08},
    9 => %{name: "UTTAR PRADESH", gst: 09},
    10 => %{name: "BIHAR", gst: 10},
    11 => %{name: "SIKKIM", gst: 11},
    12 => %{name: "ARUNACHAL PRADESH", gst: 12},
    13 => %{name: "NAGALAND", gst: 13},
    14 => %{name: "MANIPUR", gst: 14},
    15 => %{name: "MIZORAM", gst: 15},
    16 => %{name: "TRIPURA", gst: 16},
    17 => %{name: "MEGHALAYA", gst: 17},
    18 => %{name: "ASSAM", gst: 18},
    19 => %{name: "WEST BENGAL", gst: 19},
    20 => %{name: "JHARKHAND", gst: 20},
    21 => %{name: "ODISHA", gst: 21},
    22 => %{name: "CHATTISGARH", gst: 22},
    23 => %{name: "MADHYA PRADESH", gst: 23},
    24 => %{name: "GUJARAT", gst: 24},
    26 => %{name: "DADRA AND NAGAR HAVELI AND DAMAN AND DIU", gst: 26},
    27 => %{name: "MAHARASHTRA", gst: 27},
    28 => %{name: "ANDHRA PRADESH (BEFORE DIVISION)", gst: 28},
    29 => %{name: "KARNATAKA", gst: 29},
    30 => %{name: "GOA", gst: 30},
    31 => %{name: "LAKSHADWEEP", gst: 31},
    32 => %{name: "KERALA", gst: 32},
    33 => %{name: "TAMIL NADU", gst: 33},
    34 => %{name: "PUDUCHERRY", gst: 34},
    35 => %{name: "ANDAMAN AND NICOBAR ISLANDS", gst: 35},
    36 => %{name: "TELANGANA", gst: 36},
    37 => %{name: "ANDHRA PRADESH (NEWLY ADDED)", gst: 37}
  }

  @required_fields [:legal_entity_name, :pan, :place_of_supply]
  @doc false
  def changeset(legal_entity, attrs \\ %{}) do
    legal_entity
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_state_code()
    |> validate_place_of_supply()
    |> validate_pan()
    |> validate_if_gst_required()
    |> unique_constraint(:pan, name: :unique_pan_legal_entities_index, message: "A legal entity with same PAN exists.")
  end

  def get_bn_details() do
    Repo.get_by(__MODULE__, gst: "27AABCZ6271C1ZB")
  end

  def seed_data(), do: @seed_data

  @doc """
    Lists all the legal entities.
  """
  def all_legal_entities(params) do
    page_no = (params["p"] || "1") |> String.to_integer()
    get_paginated_results(page_no)
  end

  @doc """
    Lists legal entity based on uuid.
  """
  def fetch_legal_entity(uuid) do
    legal_entity = get_legal_entity_from_repo(uuid)

    if not is_nil(legal_entity) do
      legal_entity_pocs = LegalEntityPocMapping.get_legal_entity_pocs_for_legal_entity(legal_entity.id)
      legal_entity = Repo.preload(legal_entity, [:stories])
      stories_map = Enum.map(legal_entity.stories, &Map.take(&1, ~w(id name)a))

      create_legal_entity_map(legal_entity)
      |> Map.put(:legal_entity_pocs, legal_entity_pocs)
      |> Map.put(:stories, stories_map)
    end
  end

  @doc """
    Updates a legal entity based on uuid.
  """
  def update_legal_entity(
        params = %{
          "uuid" => uuid,
          "legal_entity_name" => legal_entity_name,
          "pan" => pan,
          "place_of_supply" => place_of_supply
        },
        user_map
      ) do
    billing_address = Map.get(params, "billing_address") |> parse_string()
    sac = Map.get(params, "sac")
    state_code = Map.get(params, "state_code")
    shipping_address = Map.get(params, "shipping_address") |> parse_string()
    ship_to_name = Map.get(params, "ship_to_name") |> parse_string()
    gst = Map.get(params, "gst", "")
    is_gst_required = Map.get(params, "is_gst_required", true)

    gst = parse_string(gst)
    pan = parse_string(pan)

    legal_entity = get_legal_entity_from_repo(uuid)

    cond do
      is_nil(legal_entity) ->
        {:error, "Legal Entity record not found"}

      legal_entity ->
        Repo.transaction(fn ->
          legal_entity
          |> changeset(%{
            legal_entity_name: legal_entity_name,
            billing_address: billing_address,
            gst: gst,
            pan: pan,
            sac: sac,
            state_code: state_code,
            place_of_supply: place_of_supply,
            shipping_address: shipping_address,
            ship_to_name: ship_to_name,
            is_gst_required: is_gst_required
          })
          |> AuditedRepo.update(user_map)
          |> case do
            {:ok, legal_entity} ->
              case params["legal_entity_poc_ids"] do
                legal_entity_poc_ids when is_list(legal_entity_poc_ids) ->
                  assign_pocs_to_legal_entity(legal_entity.id, legal_entity_poc_ids, user_map.user_id)
                  legal_entity

                _ ->
                  legal_entity
              end

            {:error, changeset} ->
              Repo.rollback(changeset)
          end
        end)
    end
  end

  @doc """
    Creates a legal entity based on provided params.
  """
  def create(
        params = %{
          "legal_entity_name" => legal_entity_name,
          "pan" => pan,
          "place_of_supply" => place_of_supply
        },
        user_map
      ) do
    billing_address = Map.get(params, "billing_address")
    sac = Map.get(params, "sac")
    state_code = Map.get(params, "state_code")
    shipping_address = Map.get(params, "shipping_address")
    ship_to_name = Map.get(params, "ship_to_name")
    gst = Map.get(params, "gst", "") |> parse_string()
    is_gst_required = Map.get(params, "is_gst_required", true)

    pan = String.trim(pan)

    %LegalEntity{}
    |> changeset(%{
      legal_entity_name: legal_entity_name,
      billing_address: billing_address,
      gst: gst,
      pan: pan,
      sac: sac,
      state_code: state_code,
      place_of_supply: place_of_supply,
      shipping_address: shipping_address,
      ship_to_name: ship_to_name,
      is_gst_required: is_gst_required
    })
    |> AuditedRepo.insert(user_map)
    |> case do
      {:ok, legal_entity} ->
        {:ok, create_legal_entity_map(legal_entity)}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
    Meta Data api -  Returns gst code to place of supply mapping
  """
  def get_gst_code_to_place_of_supply_map() do
    @gst_code_to_place_of_supply
  end

  @doc """
    Admin Search API - Returns list of legal entities based on search text
  """
  def get_admin_legal_entity_suggestions(params) do
    search_text = if is_nil(params["q"]), do: "", else: params["q"] |> String.downcase()

    suggestions =
      search_query_for_legal_entity(search_text)
      |> Repo.all()

    suggestions
    |> Enum.map(fn legal_entity ->
      legal_entity_map = create_legal_entity_map(legal_entity)

      legal_entity_pocs = LegalEntityPocMapping.get_legal_entity_pocs_for_legal_entity(legal_entity.id)
      Map.put(legal_entity_map, :legal_entity_pocs, legal_entity_pocs)
    end)
  end

  def update_state_code_for_legal_entity(legal_entity, state_code) do
    legal_entity
    |> changeset(%{
      state_code: state_code
    })
    |> Repo.update()
  end

  def find_or_create_legal_entity(params, user_map) do
    pan = Map.get(params, "pan")

    case get_legal_entity_by_pan(pan) do
      nil ->
        create(params, user_map)

      legal_entity ->
        {:ok, create_legal_entity_map(legal_entity)}
    end
  end

  ### Private API's

  defp get_legal_entity_by_pan(nil), do: nil

  defp get_legal_entity_by_pan(pan) do
    LegalEntity
    |> where([le], fragment("lower(?) = lower(?)", le.pan, ^pan))
    |> Repo.one()
  end

  defp validate_state_code(changeset) do
    state_code = get_field(changeset, :state_code)
    valid_state_codes = @gst_code_to_place_of_supply |> Map.values() |> Enum.map(fn id -> id.gst end)

    if Enum.member?([nil] ++ valid_state_codes, state_code) do
      changeset
    else
      add_error(changeset, :state_code, "State code is not valid.")
    end
  end

  defp validate_place_of_supply(changeset) do
    place_of_supply = get_field(changeset, :place_of_supply)
    valid_place_of_supply = @gst_code_to_place_of_supply |> Map.values() |> Enum.map(fn id -> id.name end)

    if not is_nil(place_of_supply) and Enum.member?(valid_place_of_supply, String.upcase(place_of_supply)) do
      changeset
    else
      add_error(changeset, :place_of_supply, "Place of supply is not valid.")
    end
  end

  defp validate_pan(changeset) do
    pan = get_field(changeset, :pan)
    pan_length = String.length(pan)

    if not is_nil(pan) and pan_length == 10 do
      valid_pan? = String.match?(pan, ~r/[A-Z]{5}[0-9]{4}[A-Z]{1}/i)
      if valid_pan?, do: changeset, else: add_error(changeset, :pan, "PAN is invalid.")
    else
      if is_nil(pan), do: changeset, else: add_error(changeset, :pan, "PAN is of an invalid length.")
    end
  end

  defp validate_gst(%Ecto.Changeset{valid?: true} = changeset) do
    gst = get_field(changeset, :gst)
    gst_length = String.length(gst)

    if gst_length == 15 do
      valid_state_codes = @gst_code_to_place_of_supply |> Map.values() |> Enum.map(fn id -> id.gst end)

      valid_state_code? =
        if String.match?(String.slice(gst, 0, 2), ~r/^[[:digit:]]+$/) do
          nums_state_code = String.to_integer(String.slice(gst, 0, 2), 10)
          if Enum.member?(valid_state_codes, nums_state_code), do: true, else: false
        else
          false
        end

      valid_pan? =
        if String.downcase(String.slice(gst, 2, 10)) == String.downcase(get_field(changeset, :pan)),
          do: true,
          else: false

      valid_end_gst? = String.match?(String.slice(gst, 12, 3), ~r/[A-Z0-9]{3}/i)

      if valid_state_code? and valid_pan? and valid_end_gst? do
        changeset
      else
        add_error(changeset, :gst, "GST is invalid.")
      end
    else
      add_error(changeset, :gst, "GST is of an invalid length.")
    end
  end

  defp validate_gst(changeset), do: changeset

  defp validate_if_gst_required(%Ecto.Changeset{valid?: true} = changeset) do
    is_gst_required = get_field(changeset, :is_gst_required)

    case is_gst_required do
      true ->
        validate_required(changeset, :gst)
        |> validate_gst()

      false ->
        changeset
    end
  end

  defp validate_if_gst_required(changeset), do: changeset

  def create_legal_entity_map(nil), do: nil

  def create_legal_entity_map(legal_entity) do
    %{
      "uuid" => legal_entity.uuid,
      "id" => legal_entity.id,
      "legal_entity_name" => legal_entity.legal_entity_name,
      "billing_address" => legal_entity.billing_address,
      "gst" => legal_entity.gst,
      "pan" => legal_entity.pan,
      "sac" => legal_entity.sac,
      "state_code" => legal_entity.state_code,
      "place_of_supply" => legal_entity.place_of_supply,
      "shipping_address" => legal_entity.shipping_address,
      "ship_to_name" => legal_entity.ship_to_name,
      "is_gst_required" => legal_entity.is_gst_required
    }
  end

  defp get_paginated_results(page_no) do
    limit = 30
    offset = (page_no - 1) * limit

    legal_entities =
      LegalEntity
      |> order_by(desc: :id)
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()

    legal_entites_map =
      legal_entities
      |> Enum.map(fn legal_entity ->
        legal_entity_map = create_legal_entity_map(legal_entity)

        stories = StoryLegalEntityMapping.get_stories_for_legal_entity(legal_entity.id)
        legal_entity_map = Map.put(legal_entity_map, :stories, stories)

        legal_entity_pocs = LegalEntityPocMapping.get_legal_entity_pocs_for_legal_entity(legal_entity.id)
        Map.put(legal_entity_map, :legal_entity_pocs, legal_entity_pocs)
      end)

    %{
      "legal_entities" => legal_entites_map,
      "next_page_exists" => Enum.count(legal_entities) >= limit,
      "next_page_query_params" => "p=#{page_no + 1}"
    }
  end

  defp get_legal_entity_from_repo(uuid) do
    LegalEntity
    |> Repo.get_by(uuid: uuid)
  end

  defp search_query_for_legal_entity(search_text) do
    modified_search_text = "%" <> search_text <> "%"

    query =
      if not is_nil(search_text) and search_text != "" do
        LegalEntity |> where([s], ilike(s.legal_entity_name, ^modified_search_text))
      else
        LegalEntity
      end

    query
    |> order_by([legal_entity], desc: legal_entity.updated_at, asc: legal_entity.legal_entity_name)
    |> limit(30)
  end

  defp assign_pocs_to_legal_entity(legal_entity_id, legal_entity_poc_ids, logged_in_user) do
    current_active_poc_ids = LegalEntityPocMapping.get_active_pocs_for_legal_entity(legal_entity_id)
    pocs_to_be_activated = legal_entity_poc_ids -- current_active_poc_ids
    pocs_to_be_deactivated = current_active_poc_ids -- legal_entity_poc_ids

    pocs_to_be_activated
    |> Enum.each(fn legal_entity_poc_id ->
      LegalEntityPocMapping.activate_legal_entity_poc_mapping(legal_entity_id, legal_entity_poc_id, logged_in_user)
    end)

    pocs_to_be_deactivated
    |> Enum.each(fn legal_entity_poc_id ->
      LegalEntityPocMapping.deactivate_legal_entity_poc_mapping(legal_entity_id, legal_entity_poc_id, logged_in_user)
    end)
  end

  defp parse_string(nil), do: nil

  defp parse_string(string), do: String.trim(string)
end
