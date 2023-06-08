defmodule BnApis.Commercials.CommercialPropertyPost do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Accounts
  alias BnApis.Organizations.Broker
  alias BnApis.Buildings.Building
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Commercials.CommercialPropertyPost
  alias BnApis.Places.Polygon
  alias BnApis.Commercials.CommercialPropertyPostLog
  alias BnApis.Helpers.Time
  alias BnApis.Commercials.CommercialsEnum
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Commercials.ContactedCommercialPropertyPost
  alias BnApis.Documents.Document
  alias BnApis.Commercials.CommercialSiteVisit
  alias BnApis.Commercials.CommercialPropertyPocMapping
  alias BnApis.Helpers.Utils
  alias BnApisWeb.Helpers.BuildingHelper
  alias BnApis.Commercials.CommercialSendbird
  alias BnApis.Commercials.CommercialChannelUrlMapping
  alias BnApis.Commercials.ReportedCommercialPropertyPost
  alias BnApis.Helpers.GoogleMapsHelper
  alias BnApis.Commercials.CommercialBucket
  alias BnApis.Buildings
  alias BnApis.Commercials.CommercialPropertyStatusLog

  # Statuses
  @draft "DRAFT"
  @approval_pending "APPROVAL_PENDING"
  @active "ACTIVE"
  @deactivated "DEACTIVATED"
  @deleted "DELETED"
  @default_radius 5000
  @srid 4326
  @max_range_multipler 1.1
  @min_range_multipler 0.9
  @visit_scheduled "SCHEDULED"
  @visit_completed "COMPLETED"
  @commercial_property_post_schema_name "commercial_property_posts"
  @co_working_space "CO_WORKING_SPACE"
  @city_ids_for_reminder_notification [1]

  @status_change_permission_role_mapping %{
    EmployeeRole.super().id => %{
      @active => [@approval_pending, @deactivated],
      @deactivated => [@active, @deleted],
      @approval_pending => [@draft, @active],
      @draft => [@approval_pending, @deleted],
      @deleted => [@draft]
    },
    EmployeeRole.commercial_data_collector().id => %{
      @draft => [@approval_pending, @deleted],
      @deleted => [@draft]
    },
    EmployeeRole.commercial_qc().id => %{
      @approval_pending => [@draft, @active]
    },
    EmployeeRole.commercial_ops_admin().id => %{
      @active => [@approval_pending, @deactivated],
      @deactivated => [@active, @deleted]
    },
    EmployeeRole.commercial_admin().id => %{
      @active => [@approval_pending, @deactivated],
      @approval_pending => [@draft, @active],
      @deactivated => [@active, @deleted],
      @deleted => [@draft]
    },
    EmployeeRole.commercial_agent().id => %{}
  }

  schema "commercial_property_posts" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :is_available_for_lease, :boolean, default: true
    field :is_available_for_purchase, :boolean, default: true
    field :google_maps_url, :string
    field :address, :string
    field :chargeable_area, :float
    field :carpet_area, :float
    field :premise_type, {:array, :string}, default: []
    field :efficiency, :integer
    field :floor_offer, {:array, :string}, default: []
    field :floor_plate, :integer
    field :unit_number, :string
    field :amenities, {:array, :string}, default: []
    field :handover_status, {:array, :string}, default: []
    field :is_oc_available, :boolean, default: false
    field :possession_date, :integer
    field :oc_target_date, :integer
    field :layout_plans_available, :boolean, default: false
    field :fit_out_plans_available, :boolean, default: false
    field :ownership_structure, :string
    field :price, :float
    field :property_tax, :float
    field :comman_area_maintenance, :float
    field :rent_per_month, :float
    field :property_tax_per_month, :float
    field :car_parking_slot_charge_per_month, :float
    field :common_area_maintenance_per_month, :float
    field :car_parking_slot_charge, :float
    field :security_deposit_in_number_of_months, :integer
    field :stamp_duty, :float
    field :registration_charges, :float
    field :fit_out_charges_per_month, :float
    field :society_charges, :float
    field :other_charges, :string
    field :status, :string
    field :is_it_ites_certified, :boolean, default: false
    field :number_of_seats, :integer
    field :is_ready_to_move, :boolean, default: true
    field :avg_floor_plate_carpet, :integer
    field :avg_floor_plate_charagable, :integer
    field :property_tax_included_in_price, :boolean, default: false
    field :property_tax_included_in_rent, :boolean, default: false
    field :car_charges_to_be_discussed, :boolean, default: false
    field :property_tax_to_be_discussed, :boolean, default: false
    field :common_area_maintenance_to_be_discussed, :boolean, default: false
    field :assigned_manager_ids, {:array, :integer}, default: []
    field :property_tax_per_month_to_be_discussed, :boolean, default: false
    field :security_deposit_to_be_discussed, :boolean, default: false
    field :cam_per_month_to_be_discussed, :boolean, default: false
    field :cpsc_per_month_to_be_discussed, :boolean, default: false
    field :oc_not_available, :boolean, default: false
    field :tenure, :integer
    field :escalation, :integer
    field :cost_per_seat, :integer
    field :is_include_maintenance, :boolean
    field :maintenance_cost, :float
    field :internet_charges_per_month, :float

    belongs_to(:assigned_manager, EmployeeCredential)
    belongs_to(:building, Building)
    belongs_to(:created_by, EmployeeCredential)

    timestamps()
  end

  @required [
    :number_of_seats,
    :is_available_for_lease,
    :is_available_for_purchase,
    :premise_type,
    :building_id,
    :created_by_id,
    :google_maps_url,
    :unit_number,
    :efficiency,
    :status,
    :is_it_ites_certified,
    :floor_offer
  ]

  @optional [
    :property_tax,
    :property_tax_per_month,
    :car_parking_slot_charge_per_month,
    :common_area_maintenance_per_month,
    :comman_area_maintenance,
    :car_parking_slot_charge,
    :security_deposit_in_number_of_months,
    :stamp_duty,
    :registration_charges,
    :fit_out_charges_per_month,
    :society_charges,
    :other_charges,
    :amenities,
    :is_oc_available,
    :oc_target_date,
    :layout_plans_available,
    :fit_out_plans_available,
    :possession_date,
    :ownership_structure,
    :rent_per_month,
    :price,
    :floor_plate,
    :is_ready_to_move,
    :property_tax_included_in_price,
    :property_tax_included_in_rent,
    :chargeable_area,
    :carpet_area,
    :avg_floor_plate_carpet,
    :avg_floor_plate_charagable,
    :car_charges_to_be_discussed,
    :property_tax_to_be_discussed,
    :common_area_maintenance_to_be_discussed,
    :assigned_manager_ids,
    :property_tax_per_month_to_be_discussed,
    :security_deposit_to_be_discussed,
    :cam_per_month_to_be_discussed,
    :cpsc_per_month_to_be_discussed,
    :oc_not_available,
    :address,
    :handover_status,
    :is_include_maintenance,
    :maintenance_cost
  ]

  @co_working_fields [
    :tenure,
    :escalation,
    :cost_per_seat,
    :internet_charges_per_month
  ]

  @doc false
  def changeset(commercial_property, attrs) do
    commercial_property
    |> cast(attrs, @required ++ @optional ++ @co_working_fields)
    |> validate_required(@required)
    |> custom_validate()
    |> validate_amenities()
    |> validate_purchase_fields()
    |> validate_lease_fields()
  end

  def validate_amenities(changeset) do
    amenities = get_field(changeset, :amenities)

    if(amenities in [nil, []]) do
      changeset
    else
      amenities_list = CommercialsEnum.get_amenities_identifier_list()

      if length(amenities -- amenities_list) > 0,
        do: add_error(changeset, :amenities, "Invalid amenities"),
        else: changeset
    end
  end

  def validate_purchase_fields(changeset) do
    is_available_for_purchase = get_field(changeset, :is_available_for_purchase)

    if not is_nil(is_available_for_purchase) && is_available_for_purchase == true do
      changeset
      |> validate_required([:price, :handover_status, :ownership_structure])
      |> validate_car_parking_slot_charge()
      |> validate_common_area_maintenance()
      |> validate_property_tax()
    else
      changeset
    end
  end

  def validate_car_parking_slot_charge(changeset) do
    car_charges_to_be_discussed = get_field(changeset, :car_charges_to_be_discussed)
    car_parking_slot_charge = get_field(changeset, :car_parking_slot_charge)

    if car_charges_to_be_discussed in [nil, false] and is_nil(car_parking_slot_charge) do
      add_error(changeset, :car_parking_slot_charge, "car parking slot charge is missing")
    else
      changeset
    end
  end

  def validate_common_area_maintenance(changeset) do
    common_area_maintenance_to_be_discussed = get_field(changeset, :common_area_maintenance_to_be_discussed)
    comman_area_maintenance = get_field(changeset, :comman_area_maintenance)
    premise_type = get_field(changeset, :premise_type)

    if common_area_maintenance_to_be_discussed in [nil, false] and is_nil(comman_area_maintenance) and @co_working_space not in premise_type do
      add_error(changeset, :comman_area_maintenance, "common area maintenance is missing")
    else
      changeset
    end
  end

  def validate_property_tax(changeset) do
    property_tax_to_be_discussed = get_field(changeset, :property_tax_to_be_discussed)
    property_tax_included_in_price = get_field(changeset, :property_tax_included_in_price)
    property_tax = get_field(changeset, :property_tax)

    if property_tax_to_be_discussed in [nil, false] and property_tax_included_in_price in [nil, false] and is_nil(property_tax) do
      add_error(changeset, :property_tax, "property tax is missing")
    else
      changeset
    end
  end

  def validate_lease_fields(changeset) do
    is_available_for_lease = get_field(changeset, :is_available_for_lease)

    if not is_nil(is_available_for_lease) && is_available_for_lease == true do
      changeset
      |> validate_rent_per_month()
      |> validate_common_area_maintenance_per_month()
      |> validate_security_deposit_in_number_of_months()
      |> validate_car_parking_slot_charge_per_month()
      |> validate_property_tax_per_month
      |> validate_co_working_fields()
    else
      changeset
    end
  end

  def validate_rent_per_month(changeset) do
    rent_per_month = get_field(changeset, :rent_per_month)
    premise_type = get_field(changeset, :premise_type)

    if is_nil(rent_per_month) and @co_working_space not in premise_type do
      add_error(changeset, :rent_per_month, "rent per month is missing")
    else
      changeset
    end
  end

  def validate_maintenance_cost(changeset) do
    is_include_maintenance = get_field(changeset, :is_include_maintenance)
    maintenance_cost = get_field(changeset, :maintenance_cost)

    if is_include_maintenance in [nil, false] and is_nil(maintenance_cost) do
      add_error(changeset, :maintenance_cost, "maintenance cost is missing")
    else
      changeset
    end
  end

  def validate_co_working_fields(changeset) do
    premise_type = get_field(changeset, :premise_type)

    if @co_working_space in premise_type do
      changeset
      |> validate_required(@co_working_fields)
      |> validate_maintenance_cost()
    else
      changeset
    end
  end

  def validate_common_area_maintenance_per_month(changeset) do
    cam_per_month_to_be_discussed = get_field(changeset, :cam_per_month_to_be_discussed)
    common_area_maintenance_per_month = get_field(changeset, :common_area_maintenance_per_month)
    premise_type = get_field(changeset, :premise_type)

    if cam_per_month_to_be_discussed in [nil, false] and is_nil(common_area_maintenance_per_month) and @co_working_space not in premise_type do
      add_error(changeset, :common_area_maintenance_per_month, "common area maintenance per month is missing")
    else
      changeset
    end
  end

  def validate_security_deposit_in_number_of_months(changeset) do
    security_deposit_to_be_discussed = get_field(changeset, :security_deposit_to_be_discussed)
    security_deposit_in_number_of_months = get_field(changeset, :security_deposit_in_number_of_months)

    if security_deposit_to_be_discussed in [nil, false] and is_nil(security_deposit_in_number_of_months) do
      add_error(changeset, :security_deposit_in_number_of_months, "security deposit is missing")
    else
      changeset
    end
  end

  def validate_car_parking_slot_charge_per_month(changeset) do
    car_parking_slot_charge_per_month = get_field(changeset, :car_parking_slot_charge_per_month)
    cpsc_per_month_to_be_discussed = get_field(changeset, :cpsc_per_month_to_be_discussed)

    if cpsc_per_month_to_be_discussed in [nil, false] and is_nil(car_parking_slot_charge_per_month) do
      add_error(changeset, :car_parking_slot_charge_per_month, "car parking slot charge per month is missing")
    else
      changeset
    end
  end

  def validate_property_tax_per_month(changeset) do
    property_tax_included_in_rent = get_field(changeset, :property_tax_included_in_rent)
    property_tax_per_month = get_field(changeset, :property_tax_per_month)
    property_tax_per_month_to_be_discussed = get_field(changeset, :property_tax_per_month_to_be_discussed)
    premise_type = get_field(changeset, :premise_type)

    if property_tax_included_in_rent in [nil, false] and property_tax_per_month_to_be_discussed in [nil, false] and is_nil(property_tax_per_month) and
         @co_working_space not in premise_type do
      add_error(changeset, :property_tax_per_month, "property tax per month is missing")
    else
      changeset
    end
  end

  def get_city_ids_for_reminder(), do: @city_ids_for_reminder_notification

  def fetch_update_changeset(commercial_property_post, attrs) do
    commercial_property_post
    |> changeset(attrs)
  end

  def fetch_post_by_uuid(post_uuid) do
    Repo.get_by(CommercialPropertyPost, uuid: post_uuid)
  end

  def get_schema_name do
    @commercial_property_post_schema_name
  end

  def custom_validate(changeset) do
    is_oc_available = get_field(changeset, :is_oc_available)
    oc_target_date = get_field(changeset, :oc_target_date)
    oc_not_available = get_field(changeset, :oc_not_available)
    possession_date = get_field(changeset, :possession_date)
    is_ready_to_move = get_field(changeset, :is_ready_to_move)
    premise_type = get_field(changeset, :premise_type)
    assigned_manager_ids = get_field(changeset, :assigned_manager_ids)
    floor_offer = get_field(changeset, :floor_offer)
    handover_status = get_field(changeset, :handover_status)
    ownership_structure = get_field(changeset, :ownership_structure)

    changeset =
      if floor_offer in [nil, []] do
        add_error(changeset, :floor_offer, "floor offer is missing")
      else
        changeset
      end

    changeset =
      if premise_type in [nil, []] do
        add_error(changeset, :premise_type, "premise type is missing")
      else
        changeset
      end

    changeset =
      if assigned_manager_ids in [nil, []] do
        add_error(changeset, :assigned_manager_ids, "assigned manager ids are missing")
      else
        changeset
      end

    changeset =
      if handover_status in [nil, []] and @co_working_space not in premise_type do
        add_error(changeset, :handover_status, "handover status is missing")
      else
        changeset
      end

    changeset =
      if ownership_structure in [nil, ""] and @co_working_space not in premise_type do
        add_error(changeset, :handover_status, "ownership structure is missing")
      else
        changeset
      end

    changeset =
      if oc_not_available in [false, nil] and is_oc_available in [nil, false] and is_nil(oc_target_date) and @co_working_space not in premise_type do
        add_error(changeset, :oc_target_date, "oc target date is missing")
      else
        changeset
      end

    if is_ready_to_move in [nil, false] and is_nil(possession_date) do
      add_error(changeset, :possession_date, "possession_date is missing")
    else
      changeset
    end
  end

  def update_post(params, employee_id, employee_role_id) do
    case CommercialPropertyPost.fetch_post_by_uuid(params["post_uuid"]) do
      nil ->
        {:error, "No Post found"}

      post ->
        attrs =
          params
          |> Map.take([
            "oc_target_date",
            "possession_date",
            "is_available_for_lease",
            "is_available_for_purchase",
            "google_maps_url",
            "address",
            "chargeable_area",
            "carpet_area",
            "efficiency",
            "floor_offer",
            "floor_plate",
            "unit_number",
            "is_oc_available",
            "layout_plans_available",
            "fit_out_plans_available",
            "rent_per_month",
            "price",
            "security_deposit_in_number_of_months",
            "stamp_duty",
            "registration_charges",
            "fit_out_charges_per_month",
            "society_charges",
            "other_charges",
            "is_it_ites_certified",
            "poc_ids",
            "is_ready_to_move",
            "car_parking_slot_charge_per_month",
            "common_area_maintenance_per_month",
            "assigned_manager_id",
            "avg_floor_plate_carpet",
            "avg_floor_plate_charagable",
            "property_tax_included_in_price",
            "property_tax_included_in_rent",
            "building_id",
            "car_charges_to_be_discussed",
            "property_tax_to_be_discussed",
            "common_area_maintenance_to_be_discussed",
            "car_parking_slot_charge",
            "property_tax",
            "comman_area_maintenance",
            "property_tax_per_month",
            "assigned_manager_ids",
            "property_tax_per_month_to_be_discussed",
            "security_deposit_to_be_discussed",
            "cam_per_month_to_be_discussed",
            "cpsc_per_month_to_be_discussed",
            "oc_not_available",
            "comment",
            "tenure",
            "escalation",
            "cost_per_seat",
            "is_include_maintenance",
            "internet_charges_per_month",
            "number_of_seats",
            "maintenance_cost"
          ])

        attrs =
          if params["car_charges_to_be_discussed"] == true,
            do: Map.put(attrs, "car_parking_slot_charge", nil),
            else: attrs

        attrs =
          if true in [params["property_tax_to_be_discussed"], params["property_tax_included_in_price"]],
            do: Map.put(attrs, "property_tax", nil),
            else: attrs

        attrs =
          if params["common_area_maintenance_to_be_discussed"] == true,
            do: Map.put(attrs, "comman_area_maintenance", nil),
            else: attrs

        attrs =
          if true in [params["property_tax_included_in_rent"], params["property_tax_per_month_to_be_discussed"]],
            do: Map.put(attrs, "property_tax_per_month", nil),
            else: attrs

        attrs =
          if params["security_deposit_to_be_discussed"],
            do: Map.put(attrs, "security_deposit_in_number_of_months", nil),
            else: attrs

        attrs =
          if params["cam_per_month_to_be_discussed"] == true,
            do: Map.put(attrs, "common_area_maintenance_per_month", nil),
            else: attrs

        attrs =
          if params["cpsc_per_month_to_be_discussed"] == true,
            do: Map.put(attrs, "car_parking_slot_charge_per_month", nil),
            else: attrs

        attrs =
          if not is_nil(params["premise_type_ids"]),
            do: attrs |> Map.merge(%{"premise_type" => Enum.map(params["premise_type_ids"], &CommercialsEnum.get_premise_type_identifier_from_id(&1))}),
            else: attrs

        attrs =
          if not is_nil(params["ownership_structure_id"]),
            do: attrs |> Map.merge(%{"ownership_structure" => CommercialsEnum.get_ownership_structure_identifier_from_id(params["ownership_structure_id"])}),
            else: attrs

        attrs =
          if not is_nil(params["amenity_ids"]),
            do: attrs |> Map.merge(%{"amenities" => Enum.map(params["amenity_ids"], &CommercialsEnum.get_amenities_identifier_from_id(&1))}),
            else: attrs

        attrs =
          if not is_nil(params["handover_status_ids"]),
            do: attrs |> Map.merge(%{"handover_status" => Enum.map(params["handover_status_ids"], &CommercialsEnum.get_handover_status_identifier_from_id(&1))}),
            else: attrs

        if(not is_nil(params["assigned_manager_ids"]) and is_list(params["assigned_manager_ids"])) do
          update_commercial_channel(params, post)
        end

        if not is_nil(params["status_id"]) do
          to_status_identifier = CommercialsEnum.get_property_status_identifier_from_id(params["status_id"])
          attrs = attrs |> Map.merge(%{"status" => to_status_identifier})
          {is_valid, message} = is_status_change_valid(post, employee_role_id, post.status, to_status_identifier)

          if is_valid do
            update_post_with_poc_mappings(post, attrs, params["poc_ids"], employee_id)
          else
            {:error, message}
          end
        else
          update_post_with_poc_mappings(post, attrs, params["poc_ids"], employee_id)
        end
    end
  end

  def update_status_for_multiple_posts(post_uuids, comment, status_id, user_id, employee_role_id) do
    to_status_identifier = CommercialsEnum.get_property_status_identifier_from_id(status_id)

    updated_result =
      post_uuids
      |> Enum.map(fn post_uuid ->
        get_updated_result(post_uuid, to_status_identifier, comment, employee_role_id, user_id)
      end)

    failed_update_results =
      updated_result
      |> Enum.filter(fn {flag, _message, _id} -> flag == false end)
      |> Enum.map(fn res -> %{id: res |> elem(2), reason: res |> elem(1)} end)

    res =
      cond do
        length(failed_update_results) == length(post_uuids) ->
          %{
            message: "could not update the posts",
            is_status_changed: false,
            failed_post_ids: failed_update_results
          }

        length(failed_update_results) < length(post_uuids) and length(failed_update_results) > 0 ->
          %{
            message: "partially updated",
            is_status_changed: false,
            failed_post_ids: failed_update_results
          }

        length(failed_update_results) == 0 ->
          %{
            message: "successfully updated",
            is_status_changed: true,
            failed_post_ids: []
          }
      end

    {:ok, res}
  end

  defp get_updated_result(post_uuid, to_status_identifier, comment, employee_role_id, user_id) do
    post = CommercialPropertyPost.fetch_post_by_uuid(post_uuid)
    {is_valid, message} = is_status_change_valid(post, employee_role_id, post.status, to_status_identifier)

    if is_valid do
      insert_status_change_log(post, to_status_identifier, comment, user_id)
      ch = CommercialPropertyPost.changeset(post, %{status: to_status_identifier})

      case ch |> Repo.update() do
        {:ok, _post} ->
          CommercialPropertyPostLog.log(post.id, user_id, "employee(bulk_update)", ch)
          {true, "successfully updated", 0}

        {:error, _message} ->
          {false, "could not update", post.id}
      end
    else
      {false, message, post.id}
    end
  end

  defp update_commercial_channel(params, post) do
    removed_employee_ids = post.assigned_manager_ids -- params["assigned_manager_ids"]
    added_employee_ids = params["assigned_manager_ids"] -- post.assigned_manager_ids

    if(length(added_employee_ids) > 0 or length(removed_employee_ids) > 0) do
      CommercialSendbird.update_commercial_channel(post.id, added_employee_ids, removed_employee_ids)
    end
  end

  defp insert_status_change_log(post, status_to, comment, employee_id) do
    changes = %{
      "status_from" => post.status,
      "status_to" => status_to,
      "comment" => comment,
      "commercial_property_post_id" => post.id,
      "created_by_id" => employee_id
    }

    CommercialPropertyStatusLog.create_status_log(changes)
  end

  defp update_post_with_poc_mappings(post, attrs, poc_ids, employee_id) do
    ch = post |> CommercialPropertyPost.fetch_update_changeset(attrs)

    case Repo.update(ch) do
      {:ok, commercial_property_post} ->
        CommercialPropertyPocMapping.create_and_update_poc_mapping(poc_ids, commercial_property_post.id, employee_id)
        is_status_changed = if not is_nil(attrs["status"]) and attrs["status"] !== post.status, do: true, else: false
        action_on_status_change(commercial_property_post, attrs["status"], attrs["comment"], employee_id, is_status_changed)
        commercial_property_post = commercial_property_post |> Map.put(String.to_atom("is_status_changed"), is_status_changed)

        CommercialPropertyPostLog.log(commercial_property_post.id, employee_id, "employee", ch)
        {:ok, commercial_property_post}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def action_on_status_change(_post, _status, _comment, _employee_id, false), do: nil

  def action_on_status_change(post, status, comment, employee_id, true) do
    insert_status_change_log(post, status, comment, employee_id)
    if status == @active, do: send_onboarding_msg_on_post_activation(post.id), else: nil
  end

  def create_post(params, user_id) do
    try do
      ch =
        CommercialPropertyPost.changeset(%CommercialPropertyPost{}, %{
          is_available_for_lease: params["is_available_for_lease"],
          is_available_for_purchase: params["is_available_for_purchase"],
          google_maps_url: params["google_maps_url"],
          address: params["address"],
          chargeable_area: params["chargeable_area"],
          carpet_area: params["carpet_area"],
          efficiency: params["efficiency"],
          floor_offer: params["floor_offer"],
          floor_plate: params["floor_plate"],
          unit_number: params["unit_number"],
          is_oc_available: params["is_oc_available"],
          layout_plans_available: params["layout_plans_available"],
          fit_out_plans_available: params["fit_out_plans_available"],
          rent_per_month: params["rent_per_month"],
          price: params["price"],
          property_tax: if(true in [params["property_tax_to_be_discussed"], params["property_tax_included_in_price"]], do: nil, else: params["property_tax"]),
          comman_area_maintenance: if(params["common_area_maintenance_to_be_discussed"] == true, do: nil, else: params["comman_area_maintenance"]),
          car_parking_slot_charge: if(params["car_charges_to_be_discussed"] == true, do: nil, else: params["car_parking_slot_charge"]),
          security_deposit_in_number_of_months: params["security_deposit_in_number_of_months"],
          stamp_duty: params["stamp_duty"],
          registration_charges: params["registration_charges"],
          fit_out_charges_per_month: params["fit_out_charges_per_month"],
          society_charges: params["society_charges"],
          other_charges: params["other_charges"],
          building_id: params["building_id"],
          created_by_id: user_id,
          is_it_ites_certified: params["is_it_ites_certified"],
          number_of_seats: params["number_of_seats"],
          assigned_manager_ids: params["assigned_manager_ids"],
          oc_target_date: params["oc_target_date"],
          possession_date: params["possession_date"],
          is_ready_to_move: params["is_ready_to_move"],
          property_tax_per_month: if(params["property_tax_included_in_rent"] == true, do: nil, else: params["property_tax_per_month"]),
          car_parking_slot_charge_per_month: params["car_parking_slot_charge_per_month"],
          common_area_maintenance_per_month: params["common_area_maintenance_per_month"],
          premise_type: Enum.map(params["premise_type_ids"], &CommercialsEnum.get_premise_type_identifier_from_id(&1)),
          amenities: Enum.map(params["amenity_ids"], &CommercialsEnum.get_amenities_identifier_from_id(&1)),
          handover_status: Enum.map(params["handover_status_ids"], &CommercialsEnum.get_handover_status_identifier_from_id(&1)),
          status: CommercialsEnum.get_property_status_identifier_from_id(1),
          ownership_structure: CommercialsEnum.get_ownership_structure_identifier_from_id(params["ownership_structure_id"]),
          avg_floor_plate_carpet: params["avg_floor_plate_carpet"],
          avg_floor_plate_charagable: params["avg_floor_plate_charagable"],
          property_tax_included_in_price: params["property_tax_included_in_price"],
          property_tax_included_in_rent: params["property_tax_included_in_rent"],
          car_charges_to_be_discussed: params["car_charges_to_be_discussed"],
          property_tax_to_be_discussed: params["property_tax_to_be_discussed"],
          common_area_maintenance_to_be_discussed: params["common_area_maintenance_to_be_discussed"],
          property_tax_per_month_to_be_discussed: params["property_tax_per_month_to_be_discussed"],
          cam_per_month_to_be_discussed: params["cam_per_month_to_be_discussed"],
          security_deposit_to_be_discussed: params["security_deposit_to_be_discussed"],
          cpsc_per_month_to_be_discussed: params["cpsc_per_month_to_be_discussed"],
          tenure: params["tenure"],
          escalation: params["escalation"],
          total_capacity: params["total_capacity"],
          cost_per_seat: params["cost_per_seat"],
          is_include_maintenance: params["is_include_maintenance"],
          internet_charges_per_month: params["internet_charges_per_month"],
          maintenance_cost: params["maintenance_cost"]
        })

      if ch.valid? do
        commercial_property_post = Repo.insert!(ch)

        CommercialPropertyPocMapping.create_and_update_poc_mapping(
          params["poc_ids"],
          commercial_property_post.id,
          user_id
        )

        CommercialPropertyPostLog.log(commercial_property_post.id, user_id, "employee", ch)
        params["assigned_manager_ids"] |> Enum.each(&CommercialSendbird.register_commercial_user_on_sendbird(&1))
        {:ok, commercial_property_post}
      else
        {:error, ch}
      end
    rescue
      err ->
        {:error, err}
    end
  end

  def get_building_name(post) do
    if not String.contains?(post.building.name, post.building.polygon.name) do
      "#{post.building.name}, #{post.building.polygon.name}"
    else
      post.building.name
    end
  end

  def fetch_commercial_building_details(post) do
    [latitude, longitude] = (post.building.location |> Geo.JSON.encode!())["coordinates"]

    %{
      id: post.building.id,
      uuid: post.building.uuid,
      name: get_building_name(post),
      display_address: post.building.display_address,
      car_parking_ratio: post.building.car_parking_ratio,
      total_development_size: post.building.total_development_size,
      building_grade: post.building.grade,
      building_structure: post.building.structure,
      polygon_uuid: post.building.polygon.uuid,
      locality_id: post.building.locality_id,
      sub_locality_id: post.building.sub_locality_id,
      polygon_name: post.building.polygon.name,
      polygon_id: post.building.polygon.id,
      city_id: post.building.polygon.city_id,
      latitude: latitude,
      longitude: longitude,
      building_id: post.building.id
    }
    |> Buildings.fetch_and_append_building_images()
  end

  def fetch_employee_details(employee) do
    (not is_nil(employee) and
       %{
         employee_uuid: employee.uuid,
         employee_id: employee.id,
         name: employee.name,
         phone_number: employee.phone_number,
         city_id: employee.city_id,
         employee_role_id: employee.employee_role_id
       }) || %{}
  end

  defp fetch_assigned_manager_details(assigned_manager_ids) do
    assigned_manager_ids
    |> Enum.map(fn id ->
      employee = EmployeeCredential.fetch_employee_by_id(id)

      %{
        employee_uuid: employee.uuid,
        employee_id: employee.id,
        name: employee.name,
        phone_number: employee.phone_number,
        city_id: employee.city_id,
        employee_role_id: employee.employee_role_id,
        email: employee.email,
        active: employee.active,
        country_code: employee.country_code
      }
    end)
  end

  def get_all_documents(post, "V1") do
    {post_doc, post_doc_count} = Document.get_document(post.id, @commercial_property_post_schema_name, true)
    {building_doc, building_doc_count} = Document.get_document(post.building_id, Building.get_entity_type(), true)
    {post_doc ++ building_doc, post_doc_count + building_doc_count}
  end

  def get_all_documents(post, _), do: Document.get_document(post.id, @commercial_property_post_schema_name, true)

  def get_commercial_post_details(_commercial_posts = [nil], _params), do: [nil]

  def get_commercial_post_details(commercial_posts, params) do
    commercial_posts
    |> Repo.preload([:created_by, :assigned_manager, building: [:polygon]])
    |> Enum.map(fn r ->
      building_info = fetch_commercial_building_details(r)
      created_by_employees_credentials = fetch_employee_details(r.created_by)
      assigned_manager_employees_credentials = fetch_employee_details(r.assigned_manager)

      assigned_manager_details = if r.assigned_manager_ids in [nil, []], do: [], else: fetch_assigned_manager_details(r.assigned_manager_ids)

      poc_details = CommercialPropertyPocMapping.get_commercial_poc_details(r.id)
      only_reported_posts = Map.get(params, "only_reported_posts")

      {reports, last_reported_on, first_reported_on} =
        if not is_nil(only_reported_posts) and only_reported_posts do
          ReportedCommercialPropertyPost.get_reported_data(r.id)
        else
          {%{}, nil, nil}
        end

      app_version = params |> Map.get("app_version")
      {documents, number_of_documents} = get_all_documents(r, app_version)

      formatted_properties =
        if not is_nil(app_version) and app_version == "V1" do
          format_properties_to_money(r)
        else
          format_properties_to_integer(r)
        end

      date_of_availability =
        if(r.is_ready_to_move) do
          CommercialPropertyPostLog.get_latest_activation_date(r.id)
        else
          r.possession_date
        end

      response = %{
        post_uuid: r.uuid,
        post_id: r.id,
        is_available_for_lease: r.is_available_for_lease,
        is_available_for_purchase: r.is_available_for_purchase,
        google_maps_url: r.google_maps_url,
        address: building_info.display_address,
        chargeable_area: r.chargeable_area,
        carpet_area: r.carpet_area,
        efficiency: r.efficiency,
        floor_offer: r.floor_offer,
        floor_offer_str: if(r.floor_offer in [nil], do: [], else: Enum.join(r.floor_offer, ", ")),
        floor_plate: r.floor_plate,
        unit_number: r.unit_number,
        is_oc_available: r.is_oc_available,
        oc_not_available: r.oc_not_available,
        layout_plans_available: r.layout_plans_available,
        fit_out_plans_available: r.fit_out_plans_available,
        other_charges: r.other_charges,
        is_it_ites_certified: r.is_it_ites_certified,
        number_of_seats: r.number_of_seats,
        possession_date: r.possession_date,
        oc_target_date: r.oc_target_date,
        is_ready_to_move: r.is_ready_to_move,
        premise_type_ids: Enum.map(r.premise_type, &CommercialsEnum.get_premise_type_id_from_identifier(&1)),
        premise_types: Enum.map(r.premise_type, &CommercialsEnum.get_premise_type_name_from_identifier(&1)),
        is_property_coworking: if(Enum.member?(r.premise_type, @co_working_space), do: true, else: false),
        amenity_ids: if(is_nil(r.amenities), do: [], else: get_valid_enums_value(r.amenities)),
        handover_status_ids: Enum.map(r.handover_status, &CommercialsEnum.get_handover_status_id_from_identifier(&1)),
        handover_statuses: Enum.map(r.handover_status, &CommercialsEnum.get_handover_status_name_from_identifier(&1)),
        status_id: CommercialsEnum.get_property_status_id_from_identifier(r.status),
        status: CommercialsEnum.get_property_status_display_name_from_identifier(r.status),
        ownership_structure_id: CommercialsEnum.get_ownership_structure_id_from_identifier(r.ownership_structure),
        ownership_structure: CommercialsEnum.get_ownership_structure_display_name_from_identifier(r.ownership_structure),
        building_info: building_info,
        created_by_employees_credentials: created_by_employees_credentials,
        assigned_manager_employees_credentials: assigned_manager_employees_credentials,
        poc_details: poc_details,
        documents: documents,
        document_size: number_of_documents,
        property_tax_included_in_price: set_purchase_prop(r, r.property_tax_included_in_price),
        property_tax_included_in_rent: set_lease_prop(r, r.property_tax_included_in_rent),
        reported_data: reports,
        last_reported_on: last_reported_on,
        first_reported_on: first_reported_on,
        car_charges_to_be_discussed: set_purchase_prop(r, if(is_nil(r.car_charges_to_be_discussed), do: false, else: r.car_charges_to_be_discussed)),
        property_tax_to_be_discussed: set_purchase_prop(r, if(is_nil(r.property_tax_to_be_discussed), do: false, else: r.property_tax_to_be_discussed)),
        common_area_maintenance_to_be_discussed:
          set_purchase_prop(r, if(is_nil(r.common_area_maintenance_to_be_discussed), do: false, else: r.common_area_maintenance_to_be_discussed)),
        assigned_manager_details: assigned_manager_details,
        property_tax_per_month_to_be_discussed: set_lease_prop(r, if(is_nil(r.property_tax_per_month_to_be_discussed), do: false, else: r.property_tax_per_month_to_be_discussed)),
        cam_per_month_to_be_discussed: set_lease_prop(r, if(is_nil(r.cam_per_month_to_be_discussed), do: false, else: r.cam_per_month_to_be_discussed)),
        security_deposit_to_be_discussed: set_lease_prop(r, if(is_nil(r.security_deposit_to_be_discussed), do: false, else: r.security_deposit_to_be_discussed)),
        cpsc_per_month_to_be_discussed: set_lease_prop(r, if(is_nil(r.cpsc_per_month_to_be_discussed), do: false, else: r.cpsc_per_month_to_be_discussed)),
        tenure: set_lease_prop(r, r.tenure),
        escalation: set_lease_prop(r, r.escalation),
        is_include_maintenance: set_lease_prop(r, r.is_include_maintenance),
        date_of_availability: date_of_availability
      }

      response |> Map.merge(formatted_properties)
    end)
  end

  def get_valid_enums_value(amenities) do
    valid_amenities = amenities -- amenities -- CommercialsEnum.get_amenities_identifier_list()
    valid_amenities |> Enum.map(&CommercialsEnum.get_amenities_id_from_identifier(&1))
  end

  def format_properties_to_integer(post) do
    car_parking_slot_charge = set_to_be_discuss_flag_format_float(post.car_charges_to_be_discussed, post.car_parking_slot_charge)
    property_tax = set_to_be_discuss_flag_format_float(post.property_tax_to_be_discussed, post.property_tax)
    comman_area_maintenance = set_to_be_discuss_flag_format_float(post.common_area_maintenance_to_be_discussed, post.comman_area_maintenance)
    car_parking_slot_charge_per_month = set_to_be_discuss_flag_format_float(post.cpsc_per_month_to_be_discussed, post.car_parking_slot_charge_per_month)
    common_area_maintenance_per_month = set_to_be_discuss_flag_format_float(post.cam_per_month_to_be_discussed, post.common_area_maintenance_per_month)
    security_deposit_in_number_of_months = set_to_be_discuss_flag_format_float(post.security_deposit_to_be_discussed, post.security_deposit_in_number_of_months)

    property_tax_per_month =
      cond do
        post.property_tax_included_in_rent == true -> "Included in rent"
        post.property_tax_per_month_to_be_discussed == true -> "To be discussed"
        true -> Utils.format_float(post.property_tax_per_month)
      end

    maintenance_cost = if post.is_include_maintenance in [nil, false], do: Utils.format_float(post.maintenance_cost), else: nil
    internet_and_maintenance_cost = if post.is_include_maintenance, do: post.internet_charges_per_month, else: (post.internet_charges_per_month || 0) + (post.maintenance_cost || 0)

    %{
      rent_per_month: set_lease_prop(post, Utils.format_float(post.rent_per_month)),
      price: set_purchase_prop(post, Utils.format_float(post.price)),
      property_tax: set_purchase_prop(post, property_tax),
      comman_area_maintenance: set_purchase_prop(post, comman_area_maintenance),
      car_parking_slot_charge: set_purchase_prop(post, car_parking_slot_charge),
      stamp_duty: Utils.format_float(post.stamp_duty),
      registration_charges: Utils.format_float(post.registration_charges),
      fit_out_charges_per_month: set_lease_prop(post, Utils.format_float(post.fit_out_charges_per_month)),
      society_charges: Utils.format_float(post.society_charges),
      avg_floor_plate_carpet: Utils.format_float(post.avg_floor_plate_carpet),
      avg_floor_plate_charagable: Utils.format_float(post.avg_floor_plate_charagable),
      property_tax_per_month: set_lease_prop(post, property_tax_per_month),
      car_parking_slot_charge_per_month: set_lease_prop(post, car_parking_slot_charge_per_month),
      common_area_maintenance_per_month: set_lease_prop(post, common_area_maintenance_per_month),
      security_deposit_in_number_of_months: set_lease_prop(post, security_deposit_in_number_of_months),
      internet_charges_per_month: set_lease_prop(post, Utils.format_float(post.internet_charges_per_month)),
      cost_per_seat: set_lease_prop(post, Utils.format_float(post.cost_per_seat)),
      maintenance_cost: set_lease_prop(post, maintenance_cost),
      internet_and_maintenance_cost: set_lease_prop(post, Utils.format_float(internet_and_maintenance_cost))
    }
  end

  defp set_to_be_discuss_flag_format_money(is_to_be_discussed, value) do
    case is_to_be_discussed do
      nil -> Utils.format_money(value)
      true -> "To be discussed"
      false -> Utils.format_money(value)
    end
  end

  defp set_to_be_discuss_flag_format_float(is_to_be_discussed, value) do
    case is_to_be_discussed do
      nil -> Utils.format_float(value)
      true -> "To be discussed"
      false -> Utils.format_float(value)
    end
  end

  def format_properties_to_money(post) do
    car_parking_slot_charge = set_to_be_discuss_flag_format_money(post.car_charges_to_be_discussed, post.car_parking_slot_charge)
    property_tax = set_to_be_discuss_flag_format_money(post.property_tax_to_be_discussed, post.property_tax)
    comman_area_maintenance = set_to_be_discuss_flag_format_money(post.common_area_maintenance_to_be_discussed, post.comman_area_maintenance)
    car_parking_slot_charge_per_month = set_to_be_discuss_flag_format_money(post.cpsc_per_month_to_be_discussed, post.car_parking_slot_charge_per_month)
    common_area_maintenance_per_month = set_to_be_discuss_flag_format_money(post.cam_per_month_to_be_discussed, post.common_area_maintenance_per_month)

    property_tax = if post.property_tax_included_in_price == true, do: "Included in price", else: property_tax
    maintenance_cost = if post.is_include_maintenance in [nil, false], do: Utils.format_money(post.maintenance_cost), else: nil
    internet_and_maintenance_cost = if post.is_include_maintenance, do: post.internet_charges_per_month, else: (post.internet_charges_per_month || 0) + (post.maintenance_cost || 0)

    property_tax_per_month =
      cond do
        post.property_tax_included_in_rent == true -> "Included in rent"
        post.property_tax_per_month_to_be_discussed == true -> "To be discussed"
        true -> Utils.format_money(post.property_tax_per_month)
      end

    %{
      rent_per_month: set_lease_prop(post, Utils.format_money(post.rent_per_month)),
      price: set_purchase_prop(post, Utils.format_money(post.price)),
      property_tax: set_purchase_prop(post, property_tax),
      comman_area_maintenance: set_purchase_prop(post, comman_area_maintenance),
      car_parking_slot_charge: set_purchase_prop(post, car_parking_slot_charge),
      stamp_duty: Utils.format_money(post.stamp_duty),
      registration_charges: Utils.format_money(post.registration_charges),
      fit_out_charges_per_month: set_lease_prop(post, Utils.format_money(post.fit_out_charges_per_month)),
      society_charges: Utils.format_money(post.society_charges),
      avg_floor_plate_carpet: Utils.format_money(post.avg_floor_plate_carpet),
      avg_floor_plate_charagable: Utils.format_money(post.avg_floor_plate_charagable),
      property_tax_per_month: set_lease_prop(post, property_tax_per_month),
      car_parking_slot_charge_per_month: set_lease_prop(post, car_parking_slot_charge_per_month),
      common_area_maintenance_per_month: set_lease_prop(post, common_area_maintenance_per_month),
      security_deposit_in_number_of_months: post.security_deposit_in_number_of_months,
      internet_charges_per_month: set_lease_prop(post, Utils.format_money(post.internet_charges_per_month)),
      cost_per_seat: set_lease_prop(post, Utils.format_money(post.cost_per_seat)),
      maintenance_cost: set_lease_prop(post, maintenance_cost),
      internet_and_maintenance_cost: set_lease_prop(post, Utils.format_money(internet_and_maintenance_cost))
    }
  end

  defp set_lease_prop(_post, nil), do: nil

  defp set_lease_prop(post, value) do
    if not is_nil(post.is_available_for_lease) and post.is_available_for_lease, do: value, else: nil
  end

  defp set_purchase_prop(_post, nil), do: nil

  defp set_purchase_prop(post, value) do
    if not is_nil(post.is_available_for_purchase) and post.is_available_for_purchase, do: value, else: nil
  end

  def admin_list_post(params, employee_id, employee_role_id) do
    {query, content_query, page_no, size} = CommercialPropertyPost.admin_filter_query(params, employee_id, employee_role_id)

    commercial_posts =
      content_query
      |> order_by([c, b, p, cre, ame], desc: c.inserted_at)
      |> Repo.all()
      |> get_commercial_post_details(params)
      |> get_status_comments()

    total_count = query |> distinct(:id) |> Repo.aggregate(:count, :id)
    next_page_exists = page_no < Float.ceil(total_count / size)

    response = %{
      "commercial_posts" => commercial_posts,
      "has_more" => next_page_exists,
      "total_count" => total_count,
      "next_page_query_params" => "p=#{page_no + 1}"
    }

    {:ok, response}
  end

  def admin_filter_query(params, employee_id, employee_role_id) do
    page_no = (params["p"] || "1") |> String.to_integer()
    size = (params["size"] || "20") |> String.to_integer()

    query =
      CommercialPropertyPost
      |> join(:inner, [c], b in Building, on: c.building_id == b.id)
      |> join(:inner, [c, b], p in Polygon, on: b.polygon_id == p.id)
      |> join(:inner, [c, b, p], cre in EmployeeCredential, on: c.created_by_id == cre.id)
      |> join(:left, [c, b, p, cre], ame in EmployeeCredential, on: c.assigned_manager_id == ame.id)

    query =
      if not is_nil(params["only_reported_posts"]) and params["only_reported_posts"] == true do
        reported_post_ids = ReportedCommercialPropertyPost.get_id_of_reported_post()
        query |> where([c, b, p, cre, ame], c.id in ^reported_post_ids and c.status == ^@active)
      else
        query
      end

    query =
      if not is_nil(employee_role_id) and employee_role_id == EmployeeRole.commercial_data_collector().id,
        do: query |> where([c, b, p, cre, ame], c.created_by_id == ^employee_id),
        else: query

    query =
      if not is_nil(params["commercial_post_id"]),
        do: query |> where([c, b, p, cre, ame], c.id == ^params["commercial_post_id"]),
        else: query

    query =
      if not is_nil(params["commercial_post_uuid"]),
        do: query |> where([c, b, p, cre, ame], c.uuid == ^params["commercial_post_uuid"]),
        else: query

    query =
      if not is_nil(params["polygon_ids"]),
        do: query |> where([c, b, p, cre, ame], b.polygon_id in ^params["polygon_ids"]),
        else: query

    query =
      if not is_nil(params["is_available_for_lease"]),
        do: query |> where([c, b, p, cre, ame], c.is_available_for_lease == ^params["is_available_for_lease"]),
        else: query

    query =
      if not is_nil(params["is_available_for_purchase"]),
        do: query |> where([c, b, p, cre, ame], c.is_available_for_purchase == ^params["is_available_for_purchase"]),
        else: query

    query =
      if not is_nil(params["premise_type_ids"]) && is_list(params["premise_type_ids"]) &&
           length(params["premise_type_ids"]) > 0 do
        premise_types = params["premise_type_ids"] |> Enum.map(fn p -> CommercialsEnum.get_premise_type_identifier_from_id(p) end)

        query |> where([c, b, p, cre, ame], fragment("? @> ?::varchar[]", c.premise_type, ^premise_types))
      else
        query
      end

    query =
      if not is_nil(params["amenities_list"]) && is_list(params["amenities_list"]) &&
           length(params["amenities_list"]) > 0 do
        amenities = params["amenities_list"] |> Enum.map(fn a -> CommercialsEnum.get_amenities_identifier_from_id(a) end)

        query |> where([c, b, p, cre, ame], fragment("? @> ?::varchar[]", c.amenities, ^amenities))
      else
        query
      end

    query =
      if not is_nil(params["status_id"]) do
        status = CommercialsEnum.get_property_status_identifier_from_id(params["status_id"])
        query |> where([c, b, p, cre, ame], c.status == ^status)
      else
        query
      end

    query =
      if not is_nil(params["is_oc_available"]),
        do: query |> where([c, b, p, cre, ame], c.is_oc_available == ^params["is_oc_available"]),
        else: query

    query =
      if not is_nil(params["is_ready_to_move"]),
        do: query |> where([c, b, p, cre, ame], c.is_ready_to_move == ^params["is_ready_to_move"]),
        else: query

    query =
      if not is_nil(params["layout_plans_available"]),
        do: query |> where([c, b, p, cre, ame], c.layout_plans_available == ^params["layout_plans_available"]),
        else: query

    query =
      if not is_nil(params["fit_out_plans_available"]),
        do: query |> where([c, b, p, cre, ame], c.fit_out_plans_available == ^params["fit_out_plans_available"]),
        else: query

    query =
      if not is_nil(params["status_id"]) do
        status = CommercialsEnum.get_property_status_identifier_from_id(params["status_id"])
        query |> where([c, b, p, cre, ame], c.status == ^status)
      else
        query
      end

    query =
      if not is_nil(params["is_commercial_agent"]) do
        query |> where([c, b, p, cre, ame], c.status == ^@active)
      else
        query
      end

    query =
      if not is_nil(params["building_ids"]),
        do: query |> where([c, b, p, cre, ame], c.building_id in ^params["building_ids"]),
        else: query

    query =
      if not is_nil(params["city_id"]),
        do: query |> where([c, b, p, cre, ame], p.city_id == ^params["city_id"]),
        else: query

    query =
      if not is_nil(params["created_by_name"]) do
        employee_name = params["created_by_name"]
        formatted_query = "%#{String.downcase(String.trim(employee_name))}%"
        query |> where([c, b, p, cre, ame], fragment("LOWER(?) LIKE ?", cre.name, ^formatted_query))
      else
        query
      end

    query =
      if not is_nil(params["assigned_manager_name"]) do
        assigned_manager_name = params["assigned_manager_name"]
        formatted_query = "%#{String.downcase(String.trim(assigned_manager_name))}%"
        query |> where([c, b, p, cre, ame], fragment("LOWER(?) LIKE ?", ame.name, ^formatted_query))
      else
        query
      end

    query =
      if not is_nil(params["assigned_manager_id"]) do
        query |> where([c, b, p, cre, ame], c.assigned_manager_id == ^params["assigned_manager_id"] or ^params["assigned_manager_id"] in c.assigned_manager_ids)
      else
        query
      end

    content_query =
      query
      |> limit(^size)
      |> offset(^((page_no - 1) * size))

    {query, content_query, page_no, size}
  end

  def admin_get_post(post_uuid, employee_id, employee_role_id, app_version \\ nil) do
    case fetch_post_by_uuid(post_uuid) do
      nil ->
        {:error, "Commercial Property Post not found! #{post_uuid}"}

      post ->
        case is_post_visible_to_employee(post, employee_id, employee_role_id) do
          false ->
            {:error, "Employee with employee_id #{employee_id} is not allowed to check this post"}

          true ->
            response_list = get_commercial_post_details([post], %{"app_version" => app_version})
            {:ok, hd(response_list)}
        end
    end
  end

  def meta_data() do
    CommercialsEnum.get_all_enums()
  end

  def get_post(post_uuid, user_id, visit_status \\ nil, app_version \\ nil) do
    case fetch_post_by_uuid(post_uuid) do
      nil ->
        {:error, "Commercial Property Post not found! #{post_uuid}"}

      post ->
        response_list =
          get_commercial_post_details([post], %{"app_version" => app_version})
          |> add_broker_related_fields(user_id, visit_status)

        {:ok, hd(response_list)}
    end
  end

  def list_post(params, credential_id) do
    params = params |> Map.merge(%{"status_id" => 3})
    {query, content_query, page_no, size} = filter_query(params, credential_id)

    commercial_posts =
      content_query
      |> order_by([c, b, p, cre, ame], desc: c.inserted_at)
      |> Repo.all()
      |> get_commercial_post_details(params)
      |> add_broker_related_fields(credential_id)

    total_count = query |> distinct(:id) |> Repo.aggregate(:count, :id)
    next_page_exists = page_no < Float.ceil(total_count / size)

    response = %{
      "commercial_posts" => commercial_posts,
      "has_more" => next_page_exists,
      "total_count" => total_count,
      "next_page_query_params" => "p=#{page_no + 1}"
    }

    {:ok, response}
  end

  defp filter_query(params, credential_id) do
    page_no = (params["p"] || "1") |> String.to_integer()
    size = (params["size"] || "20") |> String.to_integer()

    broker = Accounts.get_broker_by_user_id(credential_id)

    query =
      CommercialPropertyPost
      |> join(:inner, [c], b in Building, on: c.building_id == b.id)
      |> join(:inner, [c, b], p in Polygon, on: b.polygon_id == p.id)
      |> join(:inner, [c, b, p], cre in EmployeeCredential, on: c.created_by_id == cre.id)
      |> join(:left, [c, b, p, cre], ame in EmployeeCredential, on: c.assigned_manager_id == ame.id)
      |> where([c, b, p, cre], p.city_id == ^broker.operating_city)

    {param_lat, param_long} =
      if not is_nil(params["google_place_id"]) do
        google_session_token = Map.get(params, "google_session_token", "")
        place_details_response = GoogleMapsHelper.fetch_place_details(params["google_place_id"], google_session_token)
        {place_details_response.latitude, place_details_response.longitude}
      else
        if not is_nil(params["latitude"]) and not is_nil(params["longitude"]) do
          {longitude, latitude} = params |> BuildingHelper.process_geo_params()
          {latitude, longitude}
        else
          if not is_nil(params["building_id"]) do
            building = Repo.get(Building, params["building_id"])

            if not is_nil(building) do
              {latitude, longitude} = building.location.coordinates

              if not is_nil(latitude) and not is_nil(longitude) do
                {longitude, latitude} = %{"latitude" => latitude, "longitude" => longitude} |> BuildingHelper.process_geo_params()
                {latitude, longitude}
              else
                {nil, nil}
              end
            else
              {nil, nil}
            end
          else
            {nil, nil}
          end
        end
      end

    query =
      if not is_nil(param_lat) and not is_nil(param_long) do
        query
        |> where(
          [c, b],
          fragment(
            "ST_DWithin(?::geography, ST_SetSRID(ST_MakePoint(?, ?), ?), ?)",
            b.location,
            ^param_lat,
            ^param_long,
            ^@srid,
            ^@default_radius
          )
        )
      else
        query
      end

    query =
      if not is_nil(params["is_available_for_lease"]),
        do: query |> where([c, b, p, cre, ame], c.is_available_for_lease == ^params["is_available_for_lease"]),
        else: query

    query =
      if not is_nil(params["polygon_id"]),
        do: query |> where([c, b, p, cre, ame], b.polygon_id == ^params["polygon_id"]),
        else: query

    query =
      if not is_nil(params["is_available_for_purchase"]),
        do: query |> where([c, b, p, cre, ame], c.is_available_for_purchase == ^params["is_available_for_purchase"]),
        else: query

    query =
      if not is_nil(params["building_grade"]),
        do: query |> where([c, b, p, cre, ame], b.grade == ^params["building_grade"]),
        else: query

    query =
      if not is_nil(params["premise_type_list"]) && is_list(params["premise_type_list"]) &&
           length(params["premise_type_list"]) > 0 do
        premise_types = params["premise_type_list"] |> Enum.map(fn p -> CommercialsEnum.get_premise_type_identifier_from_id(p) end)

        query |> where([c, b, p, cre, ame], fragment("? @> ?::varchar[]", c.premise_type, ^premise_types))
      else
        query
      end

    query =
      if not is_nil(params["amenities_list"]) && is_list(params["amenities_list"]) &&
           length(params["amenities_list"]) > 0 do
        amenities = params["amenities_list"] |> Enum.map(fn a -> CommercialsEnum.get_amenities_identifier_from_id(a) end)

        query |> where([c, b, p, cre, ame], fragment("? @> ?::varchar[]", c.amenities, ^amenities))
      else
        query
      end

    query =
      if not is_nil(params["efficiency"]),
        do: query |> where([c, b, p, cre, ame], c.efficiency == ^params["efficiency"]),
        else: query

    query =
      if not is_nil(
           params["handover_status_ids"] && is_list(params["handover_status_ids"]) &&
             length(params["handover_status_ids"]) > 0
         ) do
        handover_statuses =
          Enum.map(
            params["handover_status_ids"],
            CommercialsEnum.get_handover_status_identifier_from_id(params["handover_status_ids"])
          )

        query |> where([c, b, p, cre, ame], fragment("? @> ?::varchar[]", c.handover_status, ^handover_statuses))
      else
        query
      end

    query =
      if not is_nil(params["is_oc_available"]),
        do: query |> where([c, b, p, cre, ame], c.is_oc_available == ^params["is_oc_available"]),
        else: query

    query =
      if not is_nil(params["is_it_ites_certified"]),
        do: query |> where([c, b, p, cre, ame], c.is_it_ites_certified == ^params["is_it_ites_certified"]),
        else: query

    query =
      if not is_nil(params["layout_plans_available"]),
        do: query |> where([c, b, p, cre, ame], c.layout_plans_available == ^params["layout_plans_available"]),
        else: query

    query =
      if not is_nil(params["fit_out_plans_available"]),
        do: query |> where([c, b, p, cre, ame], c.fit_out_plans_available == ^params["fit_out_plans_available"]),
        else: query

    query = query |> add_range_filters("number_of_seats", params["numbers_of_seats_range"])
    query = query |> add_range_filters("carpet_area", params["carpet_area_range"])
    query = query |> add_range_filters("price", params["price_range"])
    query = query |> add_range_filters("rent_per_month", params["rent_range"])
    query = query |> add_range_filters("chargeable_area", params["chargeable_area_range"])

    query =
      if not is_nil(params["is_ready_to_move"]) and params["is_ready_to_move"] do
        query |> where([c, b, p, cre, ame], c.is_ready_to_move == ^params["is_ready_to_move"])
      else
        if not is_nil(params["possession_date"]) and params["possession_date"] != "" do
          possession_date =
            if is_binary(params["possession_date"]),
              do: String.to_integer(params["possession_date"]),
              else: params["possession_date"]

          {:ok, unix_date_time} = DateTime.from_unix(possession_date)

          pd = unix_date_time |> Timex.to_date() |> Timex.to_datetime("Asia/Kolkata") |> Timex.Timezone.convert("Etc/UTC")

          start_time = pd |> Timex.beginning_of_day() |> Timex.to_datetime() |> DateTime.to_unix()
          end_time = pd |> Timex.end_of_day() |> Timex.to_datetime() |> DateTime.to_unix()
          query |> where([c, b, p, cre, ame], fragment("? BETWEEN ? AND ?", c.possession_date, ^start_time, ^end_time))
        else
          query
        end
      end

    query =
      if not is_nil(params["status_id"]) do
        status = CommercialsEnum.get_property_status_identifier_from_id(params["status_id"])
        query |> where([c, b, p, cre, ame], c.status == ^status)
      else
        query
      end

    query =
      if not is_nil(params["city_id"]),
        do: query |> where([c, b, p, cre, ame], p.city_id == ^params["city_id"]),
        else: query

    query =
      if not is_nil(params["created_by_name"]) do
        employee_name = params["created_by_name"]
        formatted_query = "%#{String.downcase(String.trim(employee_name))}%"
        query |> where([c, b, p, cre, ame], fragment("LOWER(?) LIKE ?", cre.name, ^formatted_query))
      else
        query
      end

    query =
      if not is_nil(params["assigned_manager_name"]) do
        assigned_manager_name = params["assigned_manager_name"]
        formatted_query = "%#{String.downcase(String.trim(assigned_manager_name))}%"
        query |> where([c, b, p, cre, ame], fragment("LOWER(?) LIKE ?", ame.name, ^formatted_query))
      else
        query
      end

    query =
      if not is_nil(params["sorted_by"]) && not is_nil(params["sorted_by"]["direction"]) &&
           not is_nil(params["sorted_by"]["key"]) && params["sorted_by"]["key"] !== "" and
           params["sorted_by"]["direction"] !== "" do
        direction = if params["sorted_by"]["direction"] == "asc", do: true, else: false
        key = params["sorted_by"]["key"]

        if direction do
          case key do
            "rent_per_month" ->
              query |> order_by([c, b, p, cre, ame], fragment("? asc nulls first", c.rent_per_month))

            "price" ->
              query |> order_by([c, b, p, cre, ame], fragment("? asc nulls first", c.price))

            "carpet_area" ->
              query |> order_by([c, b, p, cre, ame], fragment("? asc nulls first", c.carpet_area))

            "number_of_seats" ->
              query |> order_by([c, b, p, cre, ame], fragment("? asc nulls first", c.number_of_seats))

            "possession_date" ->
              query |> order_by([c, b, p, cre, ame], fragment("? asc nulls first", c.possession_date))

            _ ->
              if not is_nil(param_lat) and not is_nil(param_long) do
                query
                |> order_by(
                  [c, b],
                  fragment("? <-> ST_SetSRID(ST_MakePoint(?,?), ?)", b.location, ^param_lat, ^param_long, ^@srid)
                )
              else
                query |> order_by([c, b, p, cre, ame], fragment("? asc nulls first", c.updated_at))
              end
          end
        else
          case key do
            "rent_per_month" ->
              query |> order_by([c, b, p, cre, ame], fragment("? desc nulls last", c.rent_per_month))

            "price" ->
              query |> order_by([c, b, p, cre, ame], fragment("? desc nulls last", c.price))

            "carpet_area" ->
              query |> order_by([c, b, p, cre, ame], fragment("? desc nulls last", c.carpet_area))

            "number_of_seats" ->
              query |> order_by([c, b, p, cre, ame], fragment("? desc nulls last", c.number_of_seats))

            "possession_date" ->
              query |> order_by([c, b, p, cre, ame], fragment("? desc nulls last", c.possession_date))

            _ ->
              if not is_nil(param_lat) and not is_nil(param_long) do
                query
                |> order_by(
                  [c, b],
                  fragment("? <-> ST_SetSRID(ST_MakePoint(?,?), ?)", b.location, ^param_lat, ^param_long, ^@srid)
                )
              else
                query |> order_by([c, b, p, cre, ame], desc: c.updated_at)
              end
          end
        end
      else
        query |> order_by([c, b, p, cre, ame], desc: c.updated_at)
      end

    content_query =
      query
      |> limit(^size)
      |> offset(^((page_no - 1) * size))

    {query, content_query, page_no, size}
  end

  defp add_range_filters(query, key, range) do
    if not is_nil(range) && is_list(range) && length(range) == 2 do
      if List.last(range) == -1 do
        case key do
          "number_of_seats" ->
            query |> where([c, b, p, cre, ame], fragment("?  >= ?", c.number_of_seats, ^Enum.at(range, 0)))

          "carpet_area" ->
            query |> where([c, b, p, cre, ame], fragment("?  >= ?", c.carpet_area, ^Enum.at(range, 0)))

          "price" ->
            query |> where([c, b, p, cre, ame], fragment("?  >= ?", c.price, ^Enum.at(range, 0)))

          "rent_per_month" ->
            query |> where([c, b, p, cre, ame], fragment("?  >= ?", c.rent_per_month, ^Enum.at(range, 0)))

          "chargeable_area" ->
            query |> where([c, b, p, cre, ame], fragment("?  >= ?", c.chargeable_area, ^Enum.at(range, 0)))
        end
      else
        case key do
          "number_of_seats" ->
            query
            |> where(
              [c, b, p, cre, ame],
              fragment("? BETWEEN ? AND ?", c.number_of_seats, ^Enum.at(range, 0), ^Enum.at(range, 1))
            )

          "carpet_area" ->
            query
            |> where(
              [c, b, p, cre, ame],
              fragment("? BETWEEN ? AND ?", c.carpet_area, ^Enum.at(range, 0), ^Enum.at(range, 1))
            )

          "price" ->
            query
            |> where(
              [c, b, p, cre, ame],
              fragment("? BETWEEN ? AND ?", c.price, ^Enum.at(range, 0), ^Enum.at(range, 1))
            )

          "rent_per_month" ->
            query
            |> where(
              [c, b, p, cre, ame],
              fragment("? BETWEEN ? AND ?", c.rent_per_month, ^Enum.at(range, 0), ^Enum.at(range, 1))
            )

          "chargeable_area" ->
            query
            |> where(
              [c, b, p, cre, ame],
              fragment("? BETWEEN ? AND ?", c.chargeable_area, ^Enum.at(range, 0), ^Enum.at(range, 1))
            )
        end
      end
    else
      query
    end
  end

  defp is_status_change_valid(post, employee_role_id, from_status_identifier, to_status_identifier) do
    if not is_nil(@status_change_permission_role_mapping[employee_role_id]) and
         not is_nil(@status_change_permission_role_mapping[employee_role_id][from_status_identifier]) and
         to_status_identifier in @status_change_permission_role_mapping[employee_role_id][from_status_identifier] do
      {_documents, number_of_documents} = get_all_documents(post, "V1")

      cond do
        to_status_identifier == @approval_pending and number_of_documents == 0 ->
          {false, "No images found, can't change the status"}

        to_status_identifier == @active or to_status_identifier == @deactivated ->
          CommercialPropertyPost.set_property_ranges()
          {true, ""}

        true ->
          {true, ""}
      end
    else
      {false, "Current Employee is not authorized to change status from #{from_status_identifier} to #{to_status_identifier}"}
    end
  end

  def get_commercial_property_ranges() do
    CommercialPropertyPost
    |> where([c], c.status == ^@active)
    |> select([c], %{
      max_carpet_area: fragment("ceiling(max(?))", c.carpet_area),
      min_carpet_area: fragment("ceiling(min(?))", c.carpet_area),
      max_chargeable_area: fragment("ceiling(max(?))", c.chargeable_area),
      min_chargeable_area: fragment("ceiling(min(?))", c.chargeable_area),
      max_price: fragment("ceiling(max(?))", c.price),
      min_price: fragment("ceiling(min(?))", c.price),
      max_rent_per_month: fragment("ceiling(max(?))", c.rent_per_month),
      min_rent_per_month: fragment("ceiling(min(?))", c.rent_per_month)
    })
    |> Repo.all()
    |> List.first()
  end

  defp update_property_ranges(ranges, cache_range) do
    price_lb =
      if not is_nil(ranges.min_price) and ranges.min_price <= List.first(cache_range["price_range"]),
        do: set_min_range(ranges.min_price),
        else: List.first(cache_range["price_range"])

    price_hb =
      if not is_nil(ranges.max_price) and ranges.max_price >= List.last(cache_range["price_range"]),
        do: set_max_range(ranges.max_price),
        else: List.last(cache_range["price_range"])

    carpet_area_lb =
      if not is_nil(ranges.min_carpet_area) and ranges.min_carpet_area <= List.first(cache_range["carpet_area_range"]),
        do: set_min_range(ranges.min_carpet_area),
        else: List.first(cache_range["carpet_area_range"])

    carpet_area_hb =
      if not is_nil(ranges.max_carpet_area) and ranges.max_carpet_area >= List.last(cache_range["carpet_area_range"]),
        do: set_max_range(ranges.max_carpet_area),
        else: List.last(cache_range["carpet_area_range"])

    chargeable_area_lb =
      if not is_nil(ranges.min_chargeable_area) and
           ranges.min_chargeable_area <= List.first(cache_range["chargeable_area_range"]),
         do: set_min_range(ranges.min_chargeable_area),
         else: List.first(cache_range["chargeable_area_range"])

    chargeable_area_hb =
      if not is_nil(ranges.max_chargeable_area) and
           ranges.max_chargeable_area >= List.last(cache_range["chargeable_area_range"]),
         do: set_max_range(ranges.max_chargeable_area),
         else: List.last(cache_range["chargeable_area_range"])

    rent_per_month_lb =
      if not is_nil(ranges.min_rent_per_month) and
           ranges.min_rent_per_month <= List.first(cache_range["rent_per_month_range"]),
         do: set_min_range(ranges.min_rent_per_month),
         else: List.first(cache_range["rent_per_month_range"])

    rent_per_month_hb =
      if not is_nil(ranges.max_rent_per_month) and
           ranges.max_rent_per_month >= List.last(cache_range["rent_per_month_range"]),
         do: set_max_range(ranges.max_rent_per_month),
         else: List.last(cache_range["rent_per_month_range"])

    %{
      "price_range" => [Utils.format_float(price_lb), Utils.format_float(price_hb)],
      "carpet_area_range" => [Utils.format_float(carpet_area_lb), Utils.format_float(carpet_area_hb)],
      "chargeable_area_range" => [Utils.format_float(chargeable_area_lb), Utils.format_float(chargeable_area_hb)],
      "rent_per_month_range" => [Utils.format_float(rent_per_month_lb), Utils.format_float(rent_per_month_hb)]
    }
  end

  defp set_min_range(val) do
    @min_range_multipler * val
  end

  defp set_max_range(val) do
    @max_range_multipler * val
  end

  def set_property_ranges() do
    ranges = get_commercial_property_ranges()
    {:ok, cache_range} = Cachex.get(:bn_apis_cache, "commercial_post_ranges")

    case cache_range do
      nil ->
        CommercialsEnum.set_ranges_in_cache()

      cache_range ->
        updated_ranges = update_property_ranges(ranges, cache_range)
        Cachex.put(:bn_apis_cache, "commercial_post_ranges", updated_ranges)
    end
  end

  def shortlist_post(params, broker_id, user_map) do
    is_to_be_added = Utils.parse_boolean_param(params["is_to_be_added"])
    broker = Broker.fetch_broker_from_id(broker_id)
    post_uuid = params["post_uuid"]
    post_uuids = broker.shortlisted_commercial_property_posts |> Enum.map(& &1["post_uuid"])

    [status, content] =
      if is_to_be_added do
        if Enum.member?(post_uuids, post_uuid) do
          [:error, "post is already present in your shortlist"]
        else
          [
            :ok,
            %{
              "shortlisted_commercial_property_posts" =>
                [
                  %{
                    "post_uuid" => post_uuid,
                    "shortlisted_at" => NaiveDateTime.utc_now() |> Time.naive_to_epoch_in_sec()
                  }
                ] ++ broker.shortlisted_commercial_property_posts
            }
          ]
        end
      else
        if Enum.member?(post_uuids, post_uuid) do
          item = broker.shortlisted_commercial_property_posts |> Enum.find(&(&1["post_uuid"] == post_uuid))

          [
            :ok,
            %{
              "shortlisted_commercial_property_posts" => List.delete(broker.shortlisted_commercial_property_posts, item)
            }
          ]
        else
          [:error, "Post is not present in your shortlist"]
        end
      end

    if status == :ok do
      Broker.update(broker, content, user_map)

      message =
        if is_to_be_added,
          do: "You have successfully added post to the shortlist!",
          else: "You have successfully removed post from the shortlist!"

      {:ok, message}
    else
      {:error, content}
    end
  end

  def fetch_all_shortlisted_posts(params, user_id, post_uuids) do
    {query, content_query, page_no, size} = CommercialPropertyPost.shortlist_filter_query(params, post_uuids)

    commercial_posts =
      content_query
      |> order_by([c, b, p, cre], desc: c.inserted_at)
      |> Repo.all()
      |> get_commercial_post_details(params)
      |> add_broker_related_fields(user_id)

    total_count = query |> distinct(:id) |> Repo.aggregate(:count, :id)
    next_page_exists = page_no < Float.ceil(total_count / size)

    %{
      "commercial_posts" => commercial_posts,
      "has_more" => next_page_exists,
      "total_count" => total_count,
      "next_page_query_params" => "p=#{page_no + 1}"
    }
  end

  def shortlist_filter_query(params, post_ids) do
    page_no = (params["p"] || "1") |> String.to_integer()
    size = (params["size"] || "20") |> String.to_integer()

    query =
      CommercialPropertyPost
      |> where([c], c.uuid in ^post_ids and c.status == ^@active)
      |> join(:inner, [c], b in Building, on: c.building_id == b.id)
      |> join(:inner, [c, b], p in Polygon, on: b.polygon_id == p.id)
      |> join(:inner, [c, b, p], cre in EmployeeCredential, on: c.created_by_id == cre.id)

    content_query =
      query
      |> limit(^size)
      |> offset(^((page_no - 1) * size))

    {query, content_query, page_no, size}
  end

  # Private methods

  defp is_post_visible_to_employee(post, employee_id, employee_role_id) do
    if employee_role_id == EmployeeRole.commercial_data_collector().id do
      post.created_by_id == employee_id
    else
      true
    end
  end

  defp add_broker_related_fields(commercial_property_posts, user_id, visit_status \\ nil) do
    broker = Accounts.get_broker_by_user_id(user_id)

    commercial_property_posts
    |> Enum.map(fn cp ->
      closest_site_visit = CommercialSiteVisit.get_nearest_commercial_post_visit_details(broker.id, cp.post_id)
      filtered_visit = get_filtered_visit(visit_status, broker.id, cp.post_id)

      latest_contact_details = ContactedCommercialPropertyPost.get_latest_contacted_details_for_post_by_broker_id(user_id, cp.post_id)

      channel_url = CommercialChannelUrlMapping.get_commercial_url(cp.post_id, broker.id)

      visit_details =
        CommercialSiteVisit.get_all_visit_details_for_broker_id(broker.id, cp.post_id)
        |> Enum.filter(fn x -> Enum.member?(["SCHEDULED", "COMPLETED"], x.visit_status) end)

      other_properties = %{
        last_contact_details: latest_contact_details,
        filtered_visit: filtered_visit,
        is_visit_planned: if(is_nil(closest_site_visit), do: false, else: true),
        latest_visit: closest_site_visit,
        visit_details: visit_details,
        channel_url: channel_url,
        bucket_count: CommercialBucket.post_count_in_buckets(cp.post_uuid, broker.id)
      }

      cp |> Map.merge(other_properties)
    end)
    |> add_shortlist_attrs(broker)
  end

  defp get_filtered_visit(nil, _broker_id, _post_id), do: nil

  defp get_filtered_visit(visit_status, broker_id, post_id) do
    if([@visit_scheduled, @visit_completed] |> Enum.member?(visit_status)) do
      CommercialSiteVisit.get_last_visit_details_for_broker_id(visit_status, broker_id, post_id, false)
    else
      nil
    end
  end

  def add_shortlist_attrs(commercial_property_posts, broker) do
    if not is_nil(broker) do
      post_uuids = broker.shortlisted_commercial_property_posts |> Enum.map(& &1["post_uuid"])

      shortlisted_map =
        broker.shortlisted_commercial_property_posts
        |> Enum.reduce(%{}, fn shortlist, acc ->
          acc |> Map.put(shortlist["post_uuid"], shortlist["shortlisted_at"])
        end)

      commercial_property_posts
      |> Enum.map(fn post ->
        post
        |> Map.put(:is_shortlisted, Enum.member?(post_uuids, post[:post_uuid]))
        |> Map.put(:shortlisted_at, shortlisted_map[post[:post_uuid]])
      end)
    else
      commercial_property_posts
    end
  end

  def aggregate(params, employee_id, employee_role_id) do
    params =
      params
      |> Map.take([
        "city_id",
        "assigned_manager_id",
        "assigned_manager_ids",
        "only_reported_posts",
        "commercial_post_id",
        "polygon_ids",
        "is_commercial_agent",
        "building_ids",
        "assigned_manager_name"
      ])

    {query, _content_query, _page_no, _size} = CommercialPropertyPost.admin_filter_query(params, employee_id, employee_role_id)

    post_status_data = query |> group_by([c], c.status) |> select([c], %{count: count(c.id), status: c.status}) |> Repo.all()

    posts = query |> Repo.all()

    post_status_data =
      post_status_data
      |> Enum.map(fn p ->
        property_count = %{
          "purchase_count" =>
            posts
            |> Enum.filter(&(&1.is_available_for_purchase == true and &1.status == p.status))
            |> Enum.map(& &1.id)
            |> Enum.uniq()
            |> length,
          "lease_count" =>
            posts
            |> Enum.filter(&(&1.is_available_for_lease == true and &1.status == p.status))
            |> Enum.map(& &1.id)
            |> Enum.uniq()
            |> length
        }

        Map.merge(p, property_count)
      end)

    site_visit_data = CommercialSiteVisit.aggregate_visits(params)

    %{
      "post_status_count" => post_status_data,
      "site_visit" => site_visit_data
    }
  end

  def get_valid_uuids(uuids) do
    CommercialPropertyPost
    |> where([c], c.uuid in ^uuids and c.status == ^@active)
    |> select([c], %{uuid: c.uuid})
    |> Repo.all()
    |> Enum.map(& &1.uuid)
  end

  defp get_status_comments(commercial_property_posts) do
    commercial_property_posts
    |> Enum.map(fn cp ->
      comments = CommercialPropertyStatusLog.get_comments(cp.post_id)
      cp |> Map.merge(%{"comments" => comments})
    end)
  end

  def get_active_status(), do: @active

  def get_post_type(is_available_for_lease, is_available_for_purchase) do
    cond do
      is_available_for_lease and is_available_for_purchase ->
        "lease & purchase"

      is_available_for_lease == true ->
        "lease"

      is_available_for_purchase == true ->
        "purchase"
    end
  end

  def handle_whatsapp_button_webhook(button_payload, owner_phone_number) do
    post_id = button_payload["post_id"]
    action = button_payload["action"]
    auto_reply_to_whatsapp_button_response(post_id, owner_phone_number, action)
  end

  def auto_reply_to_whatsapp_button_response(post_id, owner_phone_number, "available") do
    Exq.enqueue(Exq, "send_sms", BnApis.Whatsapp.SendWhatsappMessageWorker, [
      owner_phone_number,
      "comm_avail_yes",
      [],
      %{"entity_type" => @commercial_property_post_schema_name, "entity_id" => post_id}
    ])
  end

  def auto_reply_to_whatsapp_button_response(post_id, owner_phone_number, "unavailable") do
    Exq.enqueue(Exq, "send_sms", BnApis.Whatsapp.SendWhatsappMessageWorker, [
      owner_phone_number,
      "comm_avail_no",
      [],
      %{"entity_type" => @commercial_property_post_schema_name, "entity_id" => post_id}
    ])
  end

  def send_onboarding_msg_on_post_activation(post_id) do
    Exq.enqueue(Exq, "send_sms", BnApis.Commercial.CommercialOnboardingMessage, [post_id])
  end

  def get_post_details_for_whatsapp_message(post, poc_name) do
    carpet_area = if is_nil(post.carpet_area), do: "0", else: post.carpet_area
    premise_type = post.premise_type |> Enum.map(&CommercialsEnum.get_premise_type_name_from_identifier(&1))
    handover_status = post.handover_status |> Enum.map(&CommercialsEnum.get_handover_status_name_from_identifier(&1))
    floor_offer = if post.floor_offer in [nil, []], do: "-", else: Enum.join(post.floor_offer, ", ")

    [
      "#{poc_name}",
      "#{CommercialPropertyPost.get_post_type(post.is_available_for_lease, post.is_available_for_purchase)}",
      "#{post.building.name}",
      "#{Enum.join(premise_type, ", ")}",
      "#{carpet_area}",
      "#{floor_offer}",
      "#{post.building.polygon.name} (#{post.google_maps_url})",
      "#{Enum.join(handover_status, ", ")}"
    ]
  end

  def get_image_for_onboarding_msg(post) do
    {doc, _count} = get_all_documents(post, "V1")
    building_images = doc |> Enum.filter(fn x -> x.entity_type == Building.get_entity_type() end)
    property_images = doc |> Enum.filter(fn x -> x.entity_type == @commercial_property_post_schema_name end)

    if(length(property_images) > 0) do
      property_images |> Enum.sort_by(fn x -> x.priority end) |> List.first() |> Map.get(:doc_url)
    else
      building_images |> Enum.sort_by(fn x -> x.priority end) |> List.first() |> Map.get(:doc_url)
    end
  end

  def get_whatsapp_button_reply_payload(post_id) do
    [
      %{
        index: "0",
        payload: "{\"entity_type\": \"commercial_property_posts\", \"post_id\" : \"#{post_id}\", \"action\": \"available\"}"
      },
      %{
        index: "1",
        payload: "{\"entity_type\": \"commercial_property_posts\", \"post_id\" : \"#{post_id}\", \"action\": \"unavailable\"}"
      }
    ]
  end
end
