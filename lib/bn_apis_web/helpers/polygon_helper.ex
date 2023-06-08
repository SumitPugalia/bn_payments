defmodule BnApisWeb.Helpers.PolygonHelper do
  use BnApisWeb, :view
  import Ecto.Changeset

  alias BnApis.Posts.PostType
  alias BnApis.Places.City
  alias BnApis.Helpers.{ExternalApiHelper, ApplicationHelper}

  # add fallback expiry configs
  def populate_expiry_attrs(changeset) do
    expiry_times = fallback_expiry_times()

    {rent_config_expiry, resale_config_expiry} = {get_field(changeset, :rent_config_expiry), get_field(changeset, :resale_config_expiry)}

    changeset =
      if is_nil(rent_config_expiry),
        do: change(changeset, rent_config_expiry: expiry_times[PostType.rent().name]),
        else: changeset

    if is_nil(resale_config_expiry),
      do: change(changeset, resale_config_expiry: expiry_times[PostType.resale().name]),
      else: changeset
  end

  def populate_base_filters(changeset) do
    {rent_filters, resale_filters} = {fallback_rent_filters(), fallback_resale_filters()}

    changeset =
      if is_nil(get_field(changeset, :rent_match_parameters)),
        do: change(changeset, rent_match_parameters: rent_filters),
        else: changeset

    if is_nil(get_field(changeset, :resale_match_parameters)),
      do: change(changeset, resale_match_parameters: resale_filters),
      else: changeset
  end

  def populate_city(changeset) do
    # adding by default pune city with locality
    if is_nil(get_field(changeset, :city_id)),
      do: change(changeset, city_id: ApplicationHelper.get_pune_city_id()),
      else: changeset
  end

  def fallback_expiry_times() do
    BnApis.Posts.expiry_days_map()
  end

  def fallback_rent_filters() do
    base_dynamic_rent_filters()
  end

  def fallback_resale_filters() do
    base_dynamic_resale_filters()
  end

  def polygon_predictions(query, type \\ "city") do
    ExternalApiHelper.polygon_predictions(query, type)
  end

  def fetch_cities_data() do
    City.get_cities_list()
  end

  defp base_dynamic_rent_filters() do
    %{
      rent_expected: %{
        filter: true,
        # in decimals,  20% should be added as 0.2
        max: 0.2,
        min: 0
      },
      furnishing_type_id: %{
        BnApis.Posts.FurnishingType.unfurnished().id => ["#{BnApis.Posts.FurnishingType.unfurnished().id}"],
        BnApis.Posts.FurnishingType.semi_furnished().id => ["#{BnApis.Posts.FurnishingType.semi_furnished().id}"],
        BnApis.Posts.FurnishingType.fully_furnished().id => ["#{BnApis.Posts.FurnishingType.fully_furnished().id}"],
        filter: true
      },
      configuration_type_id: create_rental_configuration_mappings()
    }
  end

  defp base_dynamic_resale_filters() do
    %{
      price: %{
        filter: true,
        # in decimals,  10% should be added as 0.1
        max: 0.2,
        min: 0
      },
      carpet_area: %{
        filter: false,
        # in decimals,  10% should be added as 0.1
        max: 0,
        min: 0
      },
      floor_type: %{
        BnApis.Posts.FloorType.lower().id => ["#{BnApis.Posts.FloorType.lower().id}"],
        BnApis.Posts.FloorType.mid().id => ["#{BnApis.Posts.FloorType.mid().id}"],
        BnApis.Posts.FloorType.higher().id => ["#{BnApis.Posts.FloorType.higher().id}"],
        filter: false
      },
      configuration_type_id: create_resale_configuration_mappings()
    }
  end

  defp create_rental_configuration_mappings() do
    %{
      BnApis.Posts.ConfigurationType.studio().id => ["#{BnApis.Posts.ConfigurationType.studio().id}"],
      BnApis.Posts.ConfigurationType.bhk_1().id => [
        "#{BnApis.Posts.ConfigurationType.studio().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_1().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_2().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_1_5().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_2().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_3().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_2_5().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_3().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_4().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_3_5().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_4().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_4_plus().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_4().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_4_plus().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_1_5().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_1().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_1_5().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_2_5().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_2().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_2_5().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_3_5().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_3().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_3_5().id}"
      ],
      filter: true
    }
  end

  defp create_resale_configuration_mappings() do
    %{
      BnApis.Posts.ConfigurationType.studio().id => ["#{BnApis.Posts.ConfigurationType.studio().id}"],
      BnApis.Posts.ConfigurationType.bhk_1().id => [
        "#{BnApis.Posts.ConfigurationType.studio().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_1().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_2().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_1_5().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_2().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_3().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_2_5().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_3().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_4().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_3_5().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_4().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_4_plus().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_4().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_4_plus().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_1_5().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_1().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_1_5().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_2_5().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_2().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_2_5().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_3_5().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_3().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_3_5().id}"
      ],
      filter: true
    }
  end
end
