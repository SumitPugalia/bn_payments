defmodule BnApis.Commercials.CommercialsEnum do
  use Ecto.Schema

  alias BnApis.Buildings.BuildingEnums
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Reasons.Reason
  alias BnApis.Commercials.CommercialPropertyPost
  alias BnApis.Helpers.Utils
  alias BnApis.Helpers.ApplicationHelper

  @commercial_property_posts "commercial_property_posts"
  @commercial_reason_type_id 6
  @report_commercial_site_visit 7
  @imgix_domain ApplicationHelper.get_imgix_domain()
  @amenities_enum %{
    1 => %{
      "id" => 1,
      "identifier" => "GYM",
      "display_name" => "Gym",
      "image_url" => "#{@imgix_domain}/commercial_amenities/gym.png"
    },
    2 => %{
      "id" => 2,
      "identifier" => "CAFÉ",
      "display_name" => "Café",
      "image_url" => "#{@imgix_domain}/commercial_amenities/cafe.png"
    },
    3 => %{
      "id" => 3,
      "identifier" => "ATM",
      "display_name" => "ATM",
      "image_url" => "#{@imgix_domain}/commercial_amenities/atm.png"
    },
    4 => %{
      "id" => 4,
      "identifier" => "DAY_CRÈCHE",
      "display_name" => "Day Crèche",
      "image_url" => "#{@imgix_domain}/commercial_amenities/day_creche.png"
    },
    5 => %{
      "id" => 5,
      "identifier" => "RESTAURANT",
      "display_name" => "Restaurant",
      "image_url" => "#{@imgix_domain}/commercial_amenities/restaurant.png"
    },
    6 => %{
      "id" => 6,
      "identifier" => "SHUTTLE_SERVICE",
      "display_name" => "Shuttle Service",
      "image_url" => "#{@imgix_domain}/commercial_amenities/shuttle_service.png"
    },
    7 => %{
      "id" => 7,
      "identifier" => "FOOD_COURT",
      "display_name" => "Food Court",
      "image_url" => "#{@imgix_domain}/commercial_amenities/food_court.png"
    },
    8 => %{
      "id" => 8,
      "identifier" => "CONCIERGE_DESK",
      "display_name" => "Concierge Desk",
      "image_url" => "#{@imgix_domain}/commercial_amenities/concierge_desk.png"
    },
    9 => %{
      "id" => 9,
      "identifier" => "RECREATION_LOUNGE",
      "display_name" => "Recreation Lounge",
      "image_url" => "#{@imgix_domain}/commercial_amenities/rescreation_lounge.png"
    },
    10 => %{
      "id" => 10,
      "identifier" => "GREEN_DECK",
      "display_name" => "Green Deck",
      "image_url" => "#{@imgix_domain}/commercial_amenities/green_desk.png"
    },
    11 => %{
      "id" => 11,
      "identifier" => "F&B_OUTLETS",
      "display_name" => "F&B Outlets",
      "image_url" => "#{@imgix_domain}/commercial_amenities/f_b_outlets.png"
    },
    12 => %{
      "id" => 12,
      "identifier" => "YOGA_DECK",
      "display_name" => "Yoga Deck",
      "image_url" => "#{@imgix_domain}/commercial_amenities/yoga.png"
    },
    13 => %{
      "id" => 13,
      "identifier" => "CLUB_HOUSE",
      "display_name" => "Club House",
      "image_url" => "#{@imgix_domain}/commercial_amenities/clubhouse.png"
    },
    14 => %{
      "id" => 14,
      "identifier" => "SWIMMING_POOL",
      "display_name" => "Swimming Pool",
      "image_url" => "#{@imgix_domain}/commercial_amenities/pool.png"
    }
  }

  @property_status_enum %{
    1 => %{
      "id" => 1,
      "identifier" => "DRAFT",
      "display_name" => "Draft"
    },
    2 => %{
      "id" => 2,
      "identifier" => "APPROVAL_PENDING",
      "display_name" => "Approval Pending"
    },
    3 => %{
      "id" => 3,
      "identifier" => "ACTIVE",
      "display_name" => "Active"
    },
    4 => %{
      "id" => 4,
      "identifier" => "DEACTIVATED",
      "display_name" => "Deactivated"
    },
    5 => %{
      "id" => 5,
      "identifier" => "DELETED",
      "display_name" => "Deleted"
    }
  }

  @premise_type_enum %{
    1 => %{
      "id" => 1,
      "identifier" => "COMMERCIAL",
      "display_name" => "Commercial"
    },
    2 => %{
      "id" => 2,
      "identifier" => "RETAIL",
      "display_name" => "Retail"
    },
    3 => %{
      "id" => 3,
      "identifier" => "IT/ITES",
      "display_name" => "IT/ITES"
    },
    4 => %{
      "id" => 4,
      "identifier" => "SEZ",
      "display_name" => "SEZ"
    },
    5 => %{
      "id" => 5,
      "identifier" => "Industrial",
      "display_name" => "Industrial"
    },
    6 => %{
      "id" => 6,
      "identifier" => "Commercial & Residential",
      "display_name" => "Commercial & Residential"
    },
    7 => %{
      "id" => 7,
      "identifier" => "Retail & Residential",
      "display_name" => "Retail & Residential"
    },
    8 => %{
      "id" => 8,
      "identifier" => "Warehouse",
      "display_name" => "Warehouse"
    },
    9 => %{
      "id" => 9,
      "identifier" => "CO_WORKING_SPACE",
      "display_name" => "Co-Working Space"
    }
  }

  @handover_status_enum %{
    1 => %{
      "id" => 1,
      "identifier" => "WARM_SHELL",
      "display_name" => "Warm Shell"
    },
    2 => %{
      "id" => 2,
      "identifier" => "BARE_SHELL",
      "display_name" => "Bare Shell"
    },
    3 => %{
      "id" => 3,
      "identifier" => "SEMI_FURNISHED",
      "display_name" => "Semi Furnished"
    },
    4 => %{
      "id" => 4,
      "identifier" => "FULLY_FURNISHED",
      "display_name" => "Fully Furnished"
    }
  }

  @ownership_structure_enum %{
    1 => %{
      "id" => 1,
      "identifier" => "DEVELOPER_OWNED",
      "display_name" => "Developer Owned"
    },
    2 => %{
      "id" => 2,
      "identifier" => "INVESTOR",
      "display_name" => "Investor"
    },
    3 => %{
      "id" => 3,
      "identifier" => "INSTITUTION_FUND",
      "display_name" => "Institution/Fund"
    },
    4 => %{
      "id" => 4,
      "identifier" => "REITS",
      "display_name" => "REITS"
    }
  }

  @visit_status_enum %{
    1 => %{
      "id" => 1,
      "identifier" => "SCHEDULED",
      "display_name" => "scheduled"
    },
    2 => %{
      "id" => 2,
      "identifier" => "COMPLETED",
      "display_name" => "completed"
    },
    3 => %{
      "id" => 3,
      "identifier" => "CANCELLED",
      "display_name" => "cancelled"
    },
    4 => %{
      "id" => 4,
      "identifier" => "DELETED",
      "display_name" => "deleted"
    }
  }

  @bucket_status_enum %{
    1 => %{
      "id" => 1,
      "identifier" => "OPTIONS",
      "display_name" => "Options",
      "image_url" => "https://broker-network.imgix.net/commercial-icons/options.png"
    },
    2 => %{
      "id" => 2,
      "identifier" => "SHORTLISTED",
      "display_name" => "Shortlisted",
      "image_url" => "https://broker-network.imgix.net/commercial-icons/shortlist.png"
    },
    3 => %{
      "id" => 3,
      "identifier" => "VISITS",
      "display_name" => "Visits",
      "image_url" => "https://broker-network.imgix.net/commercial-icons/visit.png"
    },
    4 => %{
      "id" => 4,
      "identifier" => "NEGOTIATION",
      "display_name" => "Negotiation",
      "image_url" => "https://broker-network.imgix.net/commercial-icons/negotiation.png"
    },
    5 => %{
      "id" => 5,
      "identifier" => "FINALIZED",
      "display_name" => "Finalized",
      "image_url" => "https://broker-network.imgix.net/commercial-icons/finalized.png"
    }
  }

  @employee_role_property_status_enum %{
    EmployeeRole.super().id => [2, 3, 4],
    EmployeeRole.commercial_data_collector().id => [1, 2, 5],
    EmployeeRole.commercial_qc().id => [2, 3],
    EmployeeRole.commercial_ops_admin().id => [2, 3, 4],
    EmployeeRole.commercial_admin().id => [2, 3, 4],
    EmployeeRole.commercial_agent().id => [2, 3, 4]
  }

  @no_of_seats_range [
    [0, 10],
    [10, 30],
    [30, 70],
    [70, 150],
    [150, 300],
    [300, 550],
    [550, 750],
    [750, 1000],
    [1000, -1]
  ]
  @price_range [5000, 55000]
  @carpet_area_range [500, 5000]
  @chargeable_area_range [500, 5000]
  @rent_per_month_range [35, 375]

  @amenities_identifier_id_mapping Enum.into(@amenities_enum, %{}, &{Map.get(elem(&1, 1), "identifier"), elem(&1, 0)})
  @property_status_identifier_id_mapping Enum.into(@property_status_enum, %{}, &{Map.get(elem(&1, 1), "identifier"), elem(&1, 0)})
  @premise_type_identifier_id_mapping Enum.into(@premise_type_enum, %{}, &{Map.get(elem(&1, 1), "identifier"), elem(&1, 0)})
  @handover_status_identifier_id_mapping Enum.into(@handover_status_enum, %{}, &{Map.get(elem(&1, 1), "identifier"), elem(&1, 0)})
  @visit_status_identifier_id_mapping Enum.into(@visit_status_enum, %{}, &{Map.get(elem(&1, 1), "identifier"), elem(&1, 0)})
  @ownership_structure_identifier_id_mapping Enum.into(@ownership_structure_enum, %{}, &{Map.get(elem(&1, 1), "identifier"), elem(&1, 0)})

  def commercial_property_posts do
    @commercial_property_posts
  end

  def get_property_status_identifier_from_id(id) do
    @property_status_enum[id]["identifier"]
  end

  def get_property_status_display_name_from_id(id) do
    @property_status_enum[id]["display_name"]
  end

  def get_amenities_identifier_from_id(id) do
    @amenities_enum[id]["identifier"]
  end

  def get_premise_type_identifier_from_id(id) do
    @premise_type_enum[id]["identifier"]
  end

  def get_handover_status_identifier_from_id(id) do
    @handover_status_enum[id]["identifier"]
  end

  def get_visit_status_identifier_from_id(id) do
    @visit_status_enum[id]["identifier"]
  end

  def get_ownership_structure_identifier_from_id(id) do
    @ownership_structure_enum[id]["identifier"]
  end

  def get_bucket_status_identifier_from_id(id) do
    @bucket_status_enum[id]["identifier"]
  end

  def get_property_status_id_from_identifier(identifier) do
    @property_status_identifier_id_mapping[identifier]
  end

  def get_property_status_display_name_from_identifier(identifier) do
    status_id = get_property_status_id_from_identifier(identifier)
    get_property_status_display_name_from_id(status_id)
  end

  def get_amenities_id_from_identifier(identifier) do
    @amenities_identifier_id_mapping[identifier]
  end

  def get_premise_type_id_from_identifier(identifier) do
    @premise_type_identifier_id_mapping[identifier]
  end

  def get_premise_type_name_from_identifier(identifier) do
    premise_type_id = get_premise_type_id_from_identifier(identifier)
    @premise_type_enum[premise_type_id]["display_name"]
  end

  def get_handover_status_id_from_identifier(identifier) do
    @handover_status_identifier_id_mapping[identifier]
  end

  def get_handover_status_name_from_identifier(identifier) do
    handover_status_id = get_handover_status_id_from_identifier(identifier)
    @handover_status_enum[handover_status_id]["display_name"]
  end

  def get_visit_status_id_from_identifier(identifier) do
    @visit_status_identifier_id_mapping[identifier]
  end

  def get_ownership_structure_id_from_identifier(nil), do: nil

  def get_ownership_structure_id_from_identifier(identifier) do
    @ownership_structure_identifier_id_mapping[identifier]
  end

  def get_ownership_structure_display_name_from_identifier(nil), do: nil

  def get_ownership_structure_display_name_from_identifier(identifier) do
    ownership_structure_id = get_ownership_structure_id_from_identifier(identifier)
    @ownership_structure_enum[ownership_structure_id]["display_name"]
  end

  def get_property_status_enum() do
    @property_status_enum
  end

  def get_amenities_enum() do
    @amenities_enum
  end

  def get_premise_type_enum() do
    @premise_type_enum
  end

  def get_handover_status_enum() do
    @handover_status_enum
  end

  def get_visit_status_enum() do
    @visit_status_enum
  end

  def get_employee_role_property_status_enum() do
    @employee_role_property_status_enum
  end

  def get_ownership_structure_enum() do
    @ownership_structure_enum
  end

  def get_bucket_status_enum() do
    @bucket_status_enum
  end

  def get_report_reason_list() do
    Reason.get_reasons_by_type(@commercial_reason_type_id)
    |> Enum.map(fn r ->
      %{
        id: r.id,
        display_name: r.name
      }
    end)
  end

  def get_report_site_visit_reason_list() do
    Reason.get_reasons_by_type(@report_commercial_site_visit)
    |> Enum.map(fn r ->
      %{
        id: r.id,
        display_name: r.name
      }
    end)
  end

  defp get_ranges_for_commerical() do
    {:ok, cache_range} = Cachex.get(:bn_apis_cache, "commercial_post_ranges")

    case cache_range do
      nil ->
        set_ranges_in_cache()

      cache_range ->
        cache_range
    end
  end

  def set_ranges_in_cache() do
    db_ranges = CommercialPropertyPost.get_commercial_property_ranges()

    params =
      if is_nil(db_ranges) do
        %{
          "price_range" => @price_range,
          "carpet_area_range" => @carpet_area_range,
          "chargeable_area_range" => @chargeable_area_range,
          "rent_per_month_range" => @rent_per_month_range
        }
      else
        %{
          "price_range" =>
            if(not is_nil(db_ranges.min_price) and not is_nil(db_ranges.max_price),
              do: [Utils.format_float(db_ranges.min_price), Utils.format_float(db_ranges.max_price)],
              else: @price_range
            ),
          "carpet_area_range" =>
            if(not is_nil(db_ranges.min_carpet_area) and not is_nil(db_ranges.max_carpet_area),
              do: [Utils.format_float(db_ranges.min_carpet_area), Utils.format_float(db_ranges.max_carpet_area)],
              else: @carpet_area_range
            ),
          "chargeable_area_range" =>
            if(not is_nil(db_ranges.min_chargeable_area) and not is_nil(db_ranges.max_chargeable_area),
              do: [Utils.format_float(db_ranges.min_chargeable_area), Utils.format_float(db_ranges.max_chargeable_area)],
              else: @chargeable_area_range
            ),
          "rent_per_month_range" =>
            if(not is_nil(db_ranges.min_rent_per_month) and not is_nil(db_ranges.max_rent_per_month),
              do: [Utils.format_float(db_ranges.min_rent_per_month), Utils.format_float(db_ranges.max_rent_per_month)],
              else: @rent_per_month_range
            )
        }
      end

    Cachex.put(:bn_apis_cache, "commercial_post_ranges", params)
    params
  end

  def get_all_enums() do
    commercial_ranges = get_ranges_for_commerical()

    response = %{
      "statuses" => get_property_status_enum() |> get_structured_array(),
      "amenities" => get_amenities_enum() |> get_structured_array(),
      "premise_types" => get_premise_type_enum() |> get_structured_array(),
      "handover_statuses" => get_handover_status_enum() |> get_structured_array(),
      "building_grades" => BuildingEnums.building_grade_enum() |> get_structured_array(),
      "building_types" => BuildingEnums.building_type_enum() |> get_structured_array(),
      "visit_status" => get_visit_status_enum() |> get_structured_array(),
      "ownership_structures" => get_ownership_structure_enum() |> get_structured_array(),
      "no_of_seats_range" => @no_of_seats_range,
      "employee_allowed_statues" => get_employee_role_property_status_enum(),
      "report_reasons" => get_report_reason_list(),
      "report_site_visit_reason" => get_report_site_visit_reason_list(),
      "bucket_status" => get_bucket_status_enum() |> get_structured_array()
    }

    response |> Map.merge(commercial_ranges)
  end

  def get_amenities_identifier_list() do
    get_amenities_enum() |> get_structured_array() |> Enum.map(& &1["identifier"])
  end

  defp get_structured_array(prop_enum) do
    prop_enum |> Enum.into([], fn {_k, v} -> v end)
  end

  def validate_commercial_enum_ids(ids) do
    valid_ids = get_visit_status_enum() |> get_structured_array() |> Enum.map(& &1["id"])
    Enum.filter(ids, fn el -> Enum.member?(valid_ids, el) end)
  end
end
