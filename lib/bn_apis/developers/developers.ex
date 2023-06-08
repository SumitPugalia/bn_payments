defmodule BnApis.Developers do
  @moduledoc """
  The Developers context.
  """

  import Ecto.Query, warn: false
  alias BnApis.Repo

  alias BnApis.Developers.Developer

  @doc """
  Returns the list of developers.

  ## Examples

      iex> list_developers()
      [%Developer{}, ...]

  """
  def list_developers do
    Repo.all(Developer)
  end

  @doc """
  Gets a single developer.

  Raises `Ecto.NoResultsError` if the Developer does not exist.

  ## Examples

      iex> get_developer!(123)
      %Developer{}

      iex> get_developer!(456)
      ** (Ecto.NoResultsError)

  """
  def get_developer!(id), do: Repo.get!(Developer, id)

  def get_developer_by_uuid!(uuid), do: Repo.get_by!(Developer, uuid: uuid)

  @doc """
  Creates a developer.

  ## Examples

      iex> create_developer(%{field: value})
      {:ok, %Developer{}}

      iex> create_developer(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_developer(attrs \\ %{}) do
    %Developer{}
    |> Developer.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a developer.

  ## Examples

      iex> update_developer(developer, %{field: new_value})
      {:ok, %Developer{}}

      iex> update_developer(developer, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_developer(%Developer{} = developer, attrs) do
    developer
    |> Developer.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Developer.

  ## Examples

      iex> delete_developer(developer)
      {:ok, %Developer{}}

      iex> delete_developer(developer)
      {:error, %Ecto.Changeset{}}

  """
  def delete_developer(%Developer{} = developer) do
    Repo.delete(developer)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking developer changes.

  ## Examples

      iex> change_developer(developer)
      %Ecto.Changeset{source: %Developer{}}

  """
  def change_developer(%Developer{} = developer) do
    Developer.changeset(developer, %{})
  end

  alias BnApis.Developers.MicroMarket

  @doc """
  Returns the list of micro_markets.

  ## Examples

      iex> list_micro_markets()
      [%MicroMarket{}, ...]

  """
  def list_micro_markets do
    Repo.all(MicroMarket)
  end

  @doc """
  Gets a single micro_market.

  Raises `Ecto.NoResultsError` if the Micro market does not exist.

  ## Examples

      iex> get_micro_market!(123)
      %MicroMarket{}

      iex> get_micro_market!(456)
      ** (Ecto.NoResultsError)

  """
  def get_micro_market!(id), do: Repo.get!(MicroMarket, id)

  @doc """
  Creates a micro_market.

  ## Examples

      iex> create_micro_market(%{field: value})
      {:ok, %MicroMarket{}}

      iex> create_micro_market(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_micro_market(attrs \\ %{}) do
    %MicroMarket{}
    |> MicroMarket.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a micro_market.

  ## Examples

      iex> update_micro_market(micro_market, %{field: new_value})
      {:ok, %MicroMarket{}}

      iex> update_micro_market(micro_market, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_micro_market(%MicroMarket{} = micro_market, attrs) do
    micro_market
    |> MicroMarket.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a MicroMarket.

  ## Examples

      iex> delete_micro_market(micro_market)
      {:ok, %MicroMarket{}}

      iex> delete_micro_market(micro_market)
      {:error, %Ecto.Changeset{}}

  """
  def delete_micro_market(%MicroMarket{} = micro_market) do
    Repo.delete(micro_market)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking micro_market changes.

  ## Examples

      iex> change_micro_market(micro_market)
      %Ecto.Changeset{source: %MicroMarket{}}

  """
  def change_micro_market(%MicroMarket{} = micro_market) do
    MicroMarket.changeset(micro_market, %{})
  end

  alias BnApis.Developers.Project

  @doc """
  Returns the list of projects.

  ## Examples

      iex> list_projects()
      [%Project{}, ...]

  """
  def list_projects do
    Repo.all(Project)
  end

  @doc """
  Gets a single project.

  Raises `Ecto.NoResultsError` if the Project does not exist.

  ## Examples

      iex> get_project!(123)
      %Project{}

      iex> get_project!(456)
      ** (Ecto.NoResultsError)

  """
  def get_project!(id), do: Repo.get!(Project, id)
  def get_project_by_uuid(uuid), do: Project.get_by_uuid_query(uuid) |> Repo.one!()

  @doc """
  Creates a project.

  ## Examples

      iex> create_project(%{field: value})
      {:ok, %Project{}}

      iex> create_project(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_project(attrs \\ %{}) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a project.

  ## Examples

      iex> update_project(project, %{field: new_value})
      {:ok, %Project{}}

      iex> update_project(project, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Project.

  ## Examples

      iex> delete_project(project)
      {:ok, %Project{}}

      iex> delete_project(project)
      {:error, %Ecto.Changeset{}}

  """
  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking project changes.

  ## Examples

      iex> change_project(project)
      %Ecto.Changeset{source: %Project{}}

  """
  def change_project(%Project{} = project) do
    Project.changeset(project, %{})
  end

  alias BnApis.Developers.SalesPerson

  @doc """
  Returns the list of sales_persons.

  ## Examples

      iex> list_sales_persons()
      [%SalesPerson{}, ...]

  """
  def list_sales_persons do
    Repo.all(SalesPerson)
  end

  @doc """
  Gets a single sales_person.

  Raises `Ecto.NoResultsError` if the Sales person does not exist.

  ## Examples

      iex> get_sales_person!(123)
      %SalesPerson{}

      iex> get_sales_person!(456)
      ** (Ecto.NoResultsError)

  """
  def get_sales_person!(id), do: Repo.get!(SalesPerson, id)

  @doc """
  Creates a sales_person.

  ## Examples

      iex> create_sales_person(%{field: value})
      {:ok, %SalesPerson{}}

      iex> create_sales_person(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_sales_person(attrs \\ %{}) do
    %SalesPerson{}
    |> SalesPerson.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a sales_person.

  ## Examples

      iex> update_sales_person(sales_person, %{field: new_value})
      {:ok, %SalesPerson{}}

      iex> update_sales_person(sales_person, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_sales_person(%SalesPerson{} = sales_person, attrs) do
    sales_person
    |> SalesPerson.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a SalesPerson.

  ## Examples

      iex> delete_sales_person(sales_person)
      {:ok, %SalesPerson{}}

      iex> delete_sales_person(sales_person)
      {:error, %Ecto.Changeset{}}

  """
  def delete_sales_person(%SalesPerson{} = sales_person) do
    Repo.delete(sales_person)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking sales_person changes.

  ## Examples

      iex> change_sales_person(sales_person)
      %Ecto.Changeset{source: %SalesPerson{}}

  """
  def change_sales_person(%SalesPerson{} = sales_person) do
    SalesPerson.changeset(sales_person, %{})
  end

  alias BnApis.Developers.ProjectSalesCallLog

  @doc """
  Returns the list of project_sales_call_logs.

  ## Examples

      iex> list_project_sales_call_logs()
      [%ProjectSalesCallLog{}, ...]

  """
  def list_project_sales_call_logs do
    Repo.all(ProjectSalesCallLog)
  end

  @doc """
  Gets a single project_sales_call_log.

  Raises `Ecto.NoResultsError` if the Project sales call log does not exist.

  ## Examples

      iex> get_project_sales_call_log!(123)
      %ProjectSalesCallLog{}

      iex> get_project_sales_call_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_project_sales_call_log!(id), do: Repo.get!(ProjectSalesCallLog, id)

  @doc """
  Creates a project_sales_call_log.

  ## Examples

      iex> create_project_sales_call_log(%{field: value})
      {:ok, %ProjectSalesCallLog{}}

      iex> create_project_sales_call_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_project_sales_call_log(attrs \\ %{}) do
    %ProjectSalesCallLog{}
    |> ProjectSalesCallLog.changeset(attrs)
    |> Repo.insert()
  end

  def create_sales_call_log(person_id, user_id) do
    case SalesPerson |> Repo.get_by(uuid: person_id) do
      nil ->
        {:error, "SalesPerson not found!"}

      sales_person ->
        attrs = %{
          user_id: user_id,
          sales_person_id: sales_person.id,
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }

        create_project_sales_call_log(attrs)
    end
  end

  def get_sales_call_logs(user_id) do
    ProjectSalesCallLog.sales_call_logs_query(user_id) |> Repo.all()
  end

  def get_user_recent_call_to(user_id) do
    ProjectSalesCallLog.get_user_recent_call_to(user_id)
  end

  @doc """
  Updates a project_sales_call_log.

  ## Examples

      iex> update_project_sales_call_log(project_sales_call_log, %{field: new_value})
      {:ok, %ProjectSalesCallLog{}}

      iex> update_project_sales_call_log(project_sales_call_log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_project_sales_call_log(%ProjectSalesCallLog{} = project_sales_call_log, attrs) do
    project_sales_call_log
    |> ProjectSalesCallLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ProjectSalesCallLog.

  ## Examples

      iex> delete_project_sales_call_log(project_sales_call_log)
      {:ok, %ProjectSalesCallLog{}}

      iex> delete_project_sales_call_log(project_sales_call_log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_project_sales_call_log(%ProjectSalesCallLog{} = project_sales_call_log) do
    Repo.delete(project_sales_call_log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking project_sales_call_log changes.

  ## Examples

      iex> change_project_sales_call_log(project_sales_call_log)
      %Ecto.Changeset{source: %ProjectSalesCallLog{}}

  """
  def change_project_sales_call_log(%ProjectSalesCallLog{} = project_sales_call_log) do
    ProjectSalesCallLog.changeset(project_sales_call_log, %{})
  end

  alias BnApis.Developers.SiteVisit
  alias BnApis.Helpers.ApplicationHelper

  def create_site_visits(params) do
    params
    |> Enum.each(fn param ->
      case param |> SiteVisit.create() do
        {:error, %Ecto.Changeset{} = changeset} ->
          errors = inspect(changeset.errors)
          text = "Site Visit Creation Failed for param - " <> Poison.encode!(param) <> "\n" <> "Errors - " <> errors
          channel = ApplicationHelper.get_slack_channel()
          ApplicationHelper.notify_on_slack(text, channel)

        _ ->
          :ok
      end
    end)
  end

  def get_suggestions(search_text, exclude_project_uuids) do
    Project.search_project_query(search_text, exclude_project_uuids) |> Repo.all()
  end

  def get_developer_suggestions(search_text, exclude_developer_uuids) do
    Developer.search_developer_query(search_text, exclude_developer_uuids) |> Repo.all()
  end
end
