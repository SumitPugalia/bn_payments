defmodule BnApis.Posts.RawResalePropertyPost do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo

  alias BnApis.Posts.RawResalePropertyPost
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Helpers.SlashHelper
  alias BnApis.Helpers.Utils
  alias BnApis.Posts.RawPostLogs
  alias BnApis.CustomTypes.RoundedInteger
  alias BnApis.Posts.ResalePropertyPost
  alias BnApis.Buildings.Building

  @fresh "Fresh"
  @junk "Junk"
  @draft "Draft"
  @schema_name "raw_resale_property_posts"

  def schema_name(), do: @schema_name

  schema "raw_resale_property_posts" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :source, :string
    field :sub_source, :string
    field :price, RoundedInteger

    field :name, :string
    field :country_code, :string
    field :phone, :string

    field :city, :string
    field :building, :string
    field :building_uuid, Ecto.UUID
    field :landmark, :string
    field :locality, :string
    field :building_notes, :string
    field :address, :string
    field :pincode, :string

    field :configuration, :string
    field :carpet_area, :integer
    field :car_parkings, :integer
    field :furnishing_type, :string
    field :floor, :string
    field :notes, :string

    field :token_id, :string
    field :disposition, :string
    field :reason, :string
    field :campaign_id, :string
    field :slash_reference_id, :string
    field :pushed_to_slash, :boolean
    field :is_otp_verified, :boolean

    field :utm_source, :string
    field :utm_medium, :string
    field :utm_campaign, :string
    field :gclid, :string
    field :fbclid, :string
    field :utm_map, :map
    field :webhook_payload, :map

    ## Please drop the field newly being added in build_export_query
    belongs_to :created_by_employee_credential, EmployeeCredential
    belongs_to :updated_by_employee_credential, EmployeeCredential

    timestamps()
  end

  @required []
  @optional [
    :source,
    :sub_source,
    :name,
    :country_code,
    :phone,
    :price,
    :city,
    :building,
    :landmark,
    :locality,
    :building_notes,
    :address,
    :pincode,
    :configuration,
    :carpet_area,
    :car_parkings,
    :furnishing_type,
    :floor,
    :notes,
    :token_id,
    :disposition,
    :reason,
    :campaign_id,
    :slash_reference_id,
    :pushed_to_slash,
    :is_otp_verified,
    :created_by_employee_credential_id,
    :updated_by_employee_credential_id,
    :utm_source,
    :utm_medium,
    :utm_campaign,
    :gclid,
    :fbclid,
    :utm_map,
    :webhook_payload,
    :building_uuid
  ]

  @doc false
  def changeset(raw_resale_property_post, attrs \\ %{}) do
    raw_resale_property_post
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> assoc_constraint(:updated_by_employee_credential)
  end

  def create(params, user_map \\ %{}) do
    params =
      if not is_nil(params["disposition"]),
        do: params,
        else: params |> Map.merge(%{"disposition" => @fresh})

    params = Map.put(params, "created_by_employee_credential_id", user_map[:user_id])
    params = Map.put(params, "updated_by_employee_credential_id", user_map[:user_id])
    ch = %RawResalePropertyPost{} |> changeset(params)
    raw_resale_property_post = ch |> Repo.insert!()
    RawPostLogs.log(@schema_name, raw_resale_property_post.id, user_map, ch.changes)

    if params["disposition"] != @draft,
      do: push_to_slash(raw_resale_property_post, user_map)

    {create_post_map(raw_resale_property_post)}
  end

  def update_post(user_map, params) do
    params = Map.put(params, "updated_by_employee_credential_id", user_map[:user_id])
    raw_resale_property_post = Repo.get_by(RawResalePropertyPost, uuid: params["uuid"])
    ch = RawResalePropertyPost.changeset(raw_resale_property_post, params)
    raw_resale_property_post = Repo.update!(ch)
    RawPostLogs.log(@schema_name, raw_resale_property_post.id, user_map, ch.changes)
    {create_post_map(raw_resale_property_post)}
  end

  def get_overview(params) do
    query =
      RawResalePropertyPost
      |> build_source_filter_query(params)
      |> build_city_filter_query(params)
      |> build_date_filter_query(params)
      |> build_search_query(params["search_text"])

    dispositions_overview =
      query
      |> group_by([r], r.disposition)
      |> select([r], {r.disposition, count(r.id)})
      |> Repo.all()
      |> Enum.reduce(%{}, fn rec, acc ->
        Map.put(acc, elem(rec, 0), elem(rec, 1))
      end)

    total_count = dispositions_overview |> Enum.reduce(0, fn {_k, v}, acc -> v + acc end)

    sources =
      RawResalePropertyPost
      |> where([r], not is_nil(r.source))
      |> select([r], r.source)
      |> distinct(true)
      |> order_by([r], asc: r.source)
      |> Repo.all()

    {%{dispositions_overview: dispositions_overview, sources: sources, total_count: total_count}}
  end

  def get_data(params) do
    page =
      case not is_nil(params["p"]) and Integer.parse(params["p"]) do
        {val, _} -> val
        _ -> 1
      end

    size =
      case not is_nil(params["size"]) and Integer.parse(params["size"]) do
        {val, _} -> val
        _ -> 100
      end

    query = RawResalePropertyPost |> build_common_filter_query(params)

    total_count = query |> distinct(:id) |> Repo.aggregate(:count, :id)
    has_more_posts = page < Float.ceil(total_count / size)

    data =
      query
      |> order_by(desc: :inserted_at)
      |> limit(^size)
      |> offset(^((page - 1) * size))
      |> Repo.all()
      |> Enum.map(fn post ->
        create_post_map(post)
      end)

    {%{posts: data, has_more_posts: has_more_posts}}
  end

  def build_export_query(params) do
    columns = [
      :uuid,
      :source,
      :sub_source,
      :price,
      :name,
      :country_code,
      :phone,
      :city,
      :building,
      :landmark,
      :locality,
      :building_notes,
      :address,
      :pincode,
      :configuration,
      :carpet_area,
      :car_parkings,
      :furnishing_type,
      :floor,
      :notes,
      :token_id,
      :disposition,
      :reason,
      :campaign_id,
      :slash_reference_id,
      :pushed_to_slash,
      :is_otp_verified,
      :created_by,
      :modified_by,
      :utm_source,
      :utm_medium,
      :utm_campaign,
      :gclid,
      :fbclid,
      :utm_map,
      :post_uuid,
      :inserted_at,
      :updated_at
    ]

    records =
      RawResalePropertyPost
      |> build_common_filter_query(params)
      |> order_by(desc: :inserted_at)
      |> Repo.all()

    [columns]
    |> Stream.concat(
      records
      |> Stream.map(fn record ->
        Enum.map(columns, fn
          :created_by ->
            record |> Map.get(:created_by_employee_credential) |> Map.get(:name) |> format()

          :modified_by ->
            record |> Map.get(:updated_by_employee_credential) |> Map.get(:name) |> format()

          column ->
            format(Map.get(record, column))
        end)
      end)
    )
    |> CSV.encode()
    |> Enum.to_list()
    |> to_string()
  end

  def fetch_post(params) do
    raw_resale_property_post =
      RawResalePropertyPost
      |> where(uuid: ^params["uuid"])
      |> build_join_query()
      |> build_select_query()
      |> limit(1)
      |> order_by([rrpp, rpp], desc: rpp.inserted_at)
      |> Repo.one()

    if is_nil(raw_resale_property_post) do
      {:error, :not_found}
    else
      building_uuid = maybe_add_building_uuid(raw_resale_property_post)
      raw_resale_property_post = if not is_nil(building_uuid), do: Map.put(raw_resale_property_post, :building_uuid, building_uuid), else: raw_resale_property_post
      {:ok, create_post_map(raw_resale_property_post)}
    end
  end

  def mark_as_junk(user_map, params) do
    params = params |> Map.merge(%{"disposition" => @junk})
    update_post(user_map, params)
  end

  def update_disposition(user_map, params) do
    update_post(user_map, params)
  end

  def push_to_slash(raw_resale_property_post, user_map) do
    lead_details = %{
      "lead_id" => raw_resale_property_post.uuid,
      "lead_type" => "resale",
      "customer_number" => raw_resale_property_post.phone,
      "city" => raw_resale_property_post.city,
      "source" => raw_resale_property_post.source,
      "table_name" => @schema_name,
      "table_uniq_identifier" => raw_resale_property_post.id
    }

    SlashHelper.async_push_to_slash(lead_details, user_map)
  end

  defp create_post_map(post) do
    %{
      uuid: post.uuid,
      source: post.source,
      sub_source: post.sub_source,
      price: post.price,
      name: post.name,
      country_code: post.country_code,
      phone: post.phone,
      city: post.city,
      building: post.building,
      building_uuid: post.building_uuid,
      landmark: post.landmark,
      locality: post.locality,
      building_notes: post.building_notes,
      address: post.address,
      pincode: post.pincode,
      configuration: post.configuration,
      carpet_area: post.carpet_area,
      car_parkings: post.car_parkings,
      furnishing_type: post.furnishing_type,
      floor: post.floor,
      notes: post.notes,
      token_id: post.token_id,
      disposition: post.disposition,
      reason: post.reason,
      campaign_id: post.campaign_id,
      slash_reference_id: post.slash_reference_id,
      pushed_to_slash: post.pushed_to_slash,
      is_otp_verified: post.is_otp_verified,
      created_by_employee_credential:
        get_employee_credential(post.created_by_employee_credential) || EmployeeCredential.fetch_employee_details(post.created_by_employee_credential_id),
      updated_by_employee_credential:
        get_employee_credential(post.updated_by_employee_credential) || EmployeeCredential.fetch_employee_details(post.updated_by_employee_credential_id),
      utm_source: post.utm_source,
      utm_medium: post.utm_medium,
      utm_campaign: post.utm_campaign,
      gclid: post.gclid,
      fbclid: post.fbclid,
      utm_map: post.utm_map,
      post_uuid: Map.get(post, :post_uuid),
      inserted_at: post.inserted_at |> Timex.to_datetime() |> DateTime.to_unix(),
      updated_at: post.updated_at |> Timex.to_datetime() |> DateTime.to_unix()
    }
  end

  defp build_common_filter_query(query, params) do
    query
    |> build_source_filter_query(params)
    |> build_disposition_query(params)
    |> build_city_filter_query(params)
    |> build_date_filter_query(params)
    |> build_locality_filter_query(params)
    |> build_building_filter_query(params)
    |> build_configuration_filter_query(params)
    |> build_max_price_filter_query(params)
    |> build_min_carpet_filter_query(params)
    |> build_is_bachelor_allowed_query(params)
    |> build_furnishing_types_query(params)
    |> build_search_query(params["search_text"])
    |> build_join_query()
    |> build_select_query()
  end

  defp build_source_filter_query(query, params) do
    query =
      if not is_nil(params["source"]),
        do: query |> where([r], r.source == ^params["source"]),
        else: query

    if not is_nil(params["sources"]) do
      sources =
        String.split(params["sources"], ",", trim: true)
        |> Enum.map(fn string -> string |> String.downcase() end)

      query |> where([r], fragment("LOWER(?)", r.source) in ^sources)
    else
      query
    end
  end

  defp build_date_filter_query(query, params) do
    if not is_nil(params["start_date"]) and not is_nil(params["end_date"]) do
      start_date = if is_binary(params["start_date"]), do: String.to_integer(params["start_date"]), else: params["start_date"]

      {:ok, start_date_time} = DateTime.from_unix(start_date)
      end_date = if is_binary(params["end_date"]), do: String.to_integer(params["end_date"]), else: params["end_date"]
      {:ok, end_date_time} = DateTime.from_unix(end_date)
      query |> where([r], r.inserted_at >= ^start_date_time and r.inserted_at <= ^end_date_time)
    else
      query
    end
  end

  defp build_city_filter_query(query, params) do
    query =
      if not is_nil(params["city"]) do
        search_query = "%#{String.downcase(String.trim(params["city"]))}%"
        query |> where([r], fragment("LOWER(?) LIKE ?", r.city, ^search_query))
      else
        query
      end

    if not is_nil(params["cities"]) do
      cities =
        String.split(params["cities"], ",", trim: true)
        |> Enum.map(fn string -> string |> String.downcase() end)

      query |> where([r], fragment("LOWER(?)", r.city) in ^cities)
    else
      query
    end
  end

  defp build_disposition_query(query, params) do
    if not is_nil(params["disposition"]) do
      query |> where([r], r.disposition == ^params["disposition"])
    else
      query
    end
  end

  defp build_search_query(query, nil), do: query

  defp build_search_query(query, search_text) do
    modified_search_text = Utils.get_modified_search_text(search_text)
    query |> where([r], ilike(r.name, ^modified_search_text) or ilike(r.phone, ^modified_search_text))
  end

  defp build_join_query(query) do
    query
    |> join(:left, [r], rpp in ResalePropertyPost, on: fragment("?::varchar = ?", r.uuid, rpp.raw_post_uuid))
    |> join(:left, [r, rpp], cc in EmployeeCredential, on: r.created_by_employee_credential_id == cc.id)
    |> join(:left, [r, rpp, cc], uc in EmployeeCredential, on: r.updated_by_employee_credential_id == uc.id)
  end

  defp build_select_query(query) do
    query
    |> select([rrpp, rpp, cc, uc], %{
      uuid: rrpp.uuid,
      source: rrpp.source,
      sub_source: rrpp.sub_source,
      price: rrpp.price,
      name: rrpp.name,
      country_code: rrpp.country_code,
      phone: rrpp.phone,
      city: rrpp.city,
      building: rrpp.building,
      building_uuid: rrpp.building_uuid,
      landmark: rrpp.landmark,
      locality: rrpp.locality,
      building_notes: rrpp.building_notes,
      address: rrpp.address,
      pincode: rrpp.pincode,
      configuration: rrpp.configuration,
      carpet_area: rrpp.carpet_area,
      car_parkings: rrpp.car_parkings,
      furnishing_type: rrpp.furnishing_type,
      floor: rrpp.floor,
      notes: rrpp.notes,
      token_id: rrpp.token_id,
      disposition: rrpp.disposition,
      reason: rrpp.reason,
      campaign_id: rrpp.campaign_id,
      slash_reference_id: rrpp.slash_reference_id,
      pushed_to_slash: rrpp.pushed_to_slash,
      is_otp_verified: rrpp.is_otp_verified,
      created_by_employee_credential: %{
        city_id: cc.city_id,
        employee_id: cc.id,
        employee_role_id: cc.employee_role_id,
        employee_uuid: cc.uuid,
        name: cc.name,
        phone_number: cc.phone_number
      },
      updated_by_employee_credential: %{
        city_id: uc.city_id,
        employee_id: uc.id,
        employee_role_id: uc.employee_role_id,
        employee_uuid: uc.uuid,
        name: uc.name,
        phone_number: uc.phone_number
      },
      utm_source: rrpp.utm_source,
      utm_medium: rrpp.utm_medium,
      utm_campaign: rrpp.utm_campaign,
      gclid: rrpp.gclid,
      fbclid: rrpp.fbclid,
      utm_map: rrpp.utm_map,
      post_uuid: rpp.uuid,
      inserted_at: rrpp.inserted_at,
      updated_at: rrpp.updated_at
    })
  end

  defp build_locality_filter_query(query, params) do
    query =
      if not is_nil(params["locality"]) do
        search_query = "%#{String.downcase(params["locality"])}%"
        query |> where([r], fragment("LOWER(?) LIKE ?", r.locality, ^search_query))
      else
        query
      end

    if not is_nil(params["localities"]) do
      search_query =
        Enum.reduce(params["localities"], "", fn locality, acc ->
          if acc == "" do
            acc <> "%#{String.downcase(locality)}%"
          else
            acc <> "|" <> "%#{String.downcase(locality)}%"
          end
        end)

      query |> where([r], fragment("LOWER(?) SIMILAR TO ?", r.locality, ^search_query))
    else
      query
    end
  end

  defp build_building_filter_query(query, params) do
    query =
      if not is_nil(params["building"]) do
        search_query = "%#{String.downcase(params["building"])}%"
        query |> where([r], fragment("LOWER(?) LIKE ?", r.building, ^search_query))
      else
        query
      end

    if not is_nil(params["buildings"]) do
      search_query =
        Enum.reduce(params["buildings"], "", fn building, acc ->
          if acc == "" do
            acc <> "%#{String.downcase(building)}%"
          else
            acc <> "|" <> "%#{String.downcase(building)}%"
          end
        end)

      query |> where([r], fragment("LOWER(?) SIMILAR TO ?", r.building, ^search_query))
    else
      query
    end
  end

  defp build_configuration_filter_query(query, params) do
    if not is_nil(params["configuration_types"]),
      do: query |> where([r], r.configuration in ^params["configuration_types"]),
      else: query
  end

  defp build_max_price_filter_query(query, params) do
    if not is_nil(params["max_price"]),
      do: query |> where([r], r.price <= ^params["max_price"]),
      else: query
  end

  defp build_min_carpet_filter_query(query, params) do
    if not is_nil(params["min_carpet_area"]),
      do: query |> where([r], r.carpet_area >= ^params["min_carpet_area"]),
      else: query
  end

  defp build_is_bachelor_allowed_query(query, params) do
    if not is_nil(params["is_bachelor_allowed"]),
      do: query |> where([r], r.is_bachelor_allowed == ^params["is_bachelor_allowed"]),
      else: query
  end

  defp build_furnishing_types_query(query, params) do
    if not is_nil(params["furnishing_types"]) do
      search_query =
        Enum.reduce(params["furnishing_types"], "", fn furnishing_type, acc ->
          if acc == "" do
            acc <> "#{String.downcase(furnishing_type)}"
          else
            acc <> "|" <> "#{String.downcase(furnishing_type)}"
          end
        end)

      query |> where([r], fragment("LOWER(?) SIMILAR TO ?", r.furnishing_type, ^search_query))
    else
      query
    end
  end

  ## Lazily add building_uuid
  defp maybe_add_building_uuid(raw_resale_property_post) do
    if is_nil(raw_resale_property_post.building_uuid) && raw_resale_property_post.building && raw_resale_property_post.building != "Building Not Found" do
      case Building.get_building_by_name(raw_resale_property_post.building) do
        nil ->
          nil

        building ->
          from(r in RawResalePropertyPost, where: r.uuid == ^raw_resale_property_post.uuid, update: [set: [building_uuid: ^building.uuid]])
          |> Repo.update_all([])

          building.uuid
      end
    end
  end

  defp format(%NaiveDateTime{} = value), do: value |> Timex.Timezone.convert("Etc/UTC") |> Timex.Timezone.convert("Asia/Kolkata") |> Timex.format!("%I:%M %P, %d %b, %Y", :strftime)
  defp format(value) when is_map(value), do: Jason.encode!(value)
  defp format(value) when is_list(value), do: Jason.encode!(value)
  defp format(value), do: String.replace(~s(#{value}), ~s("), "")

  defp get_employee_credential(%Ecto.Association.NotLoaded{}), do: nil
  defp get_employee_credential(employee_credential), do: employee_credential
end
