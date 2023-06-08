defmodule Mix.Tasks.PopulateProjectConnectData do
  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Developers.{Project, Developer, SalesPerson}
  import Ecto.Query

  @shortdoc "Creates Project connect and its sales person related data"
  def run(_) do
    Mix.Task.run("app.start", [])
    # remove first line from csv file that contains headers
    File.stream!("#{File.cwd!()}/priv/data/project_connect.csv")
    |> CSV.decode()
    |> Enum.to_list()
    |> Enum.map(&create_project_connect_data/1)
  end

  def create_project_connect_data({:error, _data}), do: nil

  def create_project_connect_data({:ok, data}) do
    developer_name = "NULL"

    developer =
      case Developer |> where(name: ^developer_name) |> Repo.one() do
        nil ->
          developer_changeset = Developer.changeset(%Developer{}, %{name: developer_name})

          case Repo.insert(developer_changeset) do
            {:ok, developer} ->
              developer

            {:error, changeset} ->
              Repo.rollback(changeset)
          end

        developer ->
          developer
      end

    [project_name, sales_person_name, designation, phone, phone2 | _] = data

    project_name =
      project_name
      |> String.split(" ")
      |> Enum.map(fn elem ->
        case elem |> String.length() do
          x when x < 4 -> elem
          _ -> elem |> String.capitalize()
        end
      end)
      |> Enum.join(" ")

    project =
      case Project |> where(name: ^project_name) |> Repo.one() do
        nil ->
          project_attrs = %{
            "name" => project_name,
            # not present in the csv at the moment.
            "display_address" => "Address",
            "developer_id" => developer.id
          }

          project_changeset = Project.changeset(project_attrs)

          case Repo.insert(project_changeset) do
            {:ok, project} ->
              project

            {:error, changeset} ->
              Repo.rollback(changeset)
          end

        project ->
          project
      end

    sales_person_attrs = %{
      name: sales_person_name,
      designation: designation,
      project_id: project.id
    }

    base_query =
      SalesPerson
      |> where(name: ^sales_person_name)
      |> where(project_id: ^project.id)

    case ExPhoneNumber.parse(phone, "IN") do
      {:ok, phone_number} ->
        if ExPhoneNumber.is_valid_number?(phone_number) do
          phone_number = phone_number.national_number |> to_string
          query = base_query |> where(phone_number: ^phone_number)

          case query |> Repo.one() do
            nil ->
              sales_person_params = sales_person_attrs |> Map.merge(%{phone_number: phone_number})
              sales_person_changeset = SalesPerson.changeset(%SalesPerson{}, sales_person_params)
              Repo.insert(sales_person_changeset)

            sales_person ->
              sales_person
          end
        end

        case ExPhoneNumber.parse(phone2, "IN") do
          {:ok, phone_number2} ->
            if ExPhoneNumber.is_valid_number?(phone_number2) do
              phone_number2 = phone_number2.national_number |> to_string
              query = base_query |> where(phone_number: ^phone_number2)

              case query |> Repo.one() do
                nil ->
                  sales_person_params = sales_person_attrs |> Map.merge(%{phone_number: phone_number2})
                  sales_person_changeset = SalesPerson.changeset(%SalesPerson{}, sales_person_params)
                  Repo.insert(sales_person_changeset)

                sales_person ->
                  sales_person
              end
            end

          _ ->
            IO.puts("invalid phone number")
        end

      _ ->
        IO.puts("invalid phone number")
    end

    IO.puts("Project #{Enum.at(data, 0)} created")
  end
end
