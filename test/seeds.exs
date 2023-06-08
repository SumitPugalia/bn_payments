alias BnApis.Repo
alias BnApis.Accounts.ProfileType
import Ecto.Query

if !Repo.get_by(ProfileType, id: 1) do
  for element <- ProfileType.seed_data() do
    ProfileType.changeset(element)
    |> Repo.insert!()
  end
end

alias BnApis.Accounts.EmployeeRole

if !Repo.get_by(EmployeeRole, id: 1) do
  for element <- EmployeeRole.seed_data() do
    EmployeeRole.changeset(element)
    |> Repo.insert!()
  end
end

alias BnApis.Organizations.BrokerRole

if !Repo.get_by(BrokerRole, id: 1) do
  for element <- BrokerRole.seed_data() do
    BrokerRole.changeset(element)
    |> Repo.insert!()
  end
end

alias BnApis.Places.City

if !Repo.get_by(City, id: 1) do
  for element <- City.seed_data() do
    City.changeset(element)
    |> Repo.insert!()
  end
end

alias BnApis.Places.Polygon

if !Repo.get_by(Polygon, name: "test_polygon") do
  %Polygon{}
  |> Polygon.changeset(%{
    name: "test_polygon",
    rent_config_expiry: %{},
    resale_config_expiry: %{},
    rent_match_parameters: %{},
    resale_match_parameters: %{},
    city_id: 1
  })
  |> Repo.insert()
end

# ===================================
BnApis.Posts.ConfigurationType.seed_data()
|> Enum.each(fn config_type ->
  if BnApis.Posts.ConfigurationType |> where(name: ^config_type.name) |> where(id: ^config_type.id) |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Posts.ConfigurationType.changeset(config_type) |> Repo.insert!()
  end
end)

# ===================================
BnApis.Posts.FurnishingType.seed_data()
|> Enum.each(fn furnish_type ->
  if BnApis.Posts.FurnishingType |> where(name: ^furnish_type.name) |> where(id: ^furnish_type.id) |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Posts.FurnishingType.changeset(furnish_type) |> Repo.insert!()
  end
end)

if !Repo.get_by(BnApis.Buildings.Building, name: "Test Castle") do
  BnApis.Buildings.Building.changeset(%{
    name: "Test Castle",
    display_address: "Allard Institute, Kasarai Road, Marunje, P-2, Hinjewadi",
    polygon_id: 1,
    type: "residential",
    location: %Geo.Point{coordinates: {18.6124803, 73.7472377}, srid: 4326}
  })
  |> Repo.insert()
end

BnApis.Reasons.ReasonType.seed_data()
|> Enum.each(fn reason_type ->
  if BnApis.Reasons.ReasonType |> where(id: ^reason_type.id) |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Reasons.ReasonType.changeset(reason_type) |> Repo.insert!()
  end
end)

# ===================================

BnApis.Reasons.Reason.seed_data()
|> Enum.each(fn reason ->
  if BnApis.Reasons.Reason |> where(id: ^reason.id) |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Reasons.Reason.changeset(reason) |> Repo.insert!()
  end
end)
