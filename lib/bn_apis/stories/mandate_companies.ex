defmodule BnApis.Stories.MandateCompanies do
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Helpers.{AuditedRepo, Utils}
  alias BnApis.Stories.Schema.MandateCompany

  @doc """
    Lists all the Mandate Companies.
  """
  def all_mandate_companies(params) do
    page_no = Map.get(params, "p", "1") |> Utils.parse_to_integer() |> max(1)
    limit = Map.get(params, "limit", "30") |> Utils.parse_to_integer() |> max(1) |> min(100)
    mandate_company_name = Map.get(params, "mandate_company_name") |> parse_string()
    get_paginated_results(page_no, limit, mandate_company_name)
  end

  @doc """
    Fetches a mandate company based on id.
  """
  def fetch_mandate_company(id) do
    MandateCompany
    |> Repo.get_by(id: id)
  end

  @doc """
    Creates a Mandate Company based on provided params.
  """
  def create_mandate_company(
        _params = %{
          "mandate_company_name" => mandate_company_name
        },
        user_map
      ) do
    mandate_company_name = String.trim(mandate_company_name)

    %MandateCompany{}
    |> MandateCompany.changeset(%{
      mandate_company_name: mandate_company_name
    })
    |> AuditedRepo.insert(user_map)
  end

  def create_mandate_company(_params, _user_map), do: {:error, "Invalid params"}

  @doc """
    Updates a mandate company based on id.
  """
  def update_mandate_company(
        _params = %{
          "id" => id,
          "mandate_company_name" => mandate_company_name
        },
        user_map
      ) do
    mandate_company_name = String.trim(mandate_company_name)
    mandate_company = fetch_mandate_company(id)

    cond do
      is_nil(mandate_company) ->
        {:error, :not_found}

      mandate_company ->
        mandate_company
        |> MandateCompany.changeset(%{
          mandate_company_name: mandate_company_name
        })
        |> AuditedRepo.update(user_map)
    end
  end

  def update_mandate_company(_params, _user_map), do: {:error, "Invalid params"}

  @doc """
    Admin Search API - Returns a list of Mandate Companies based on search text
  """
  def admin_search_mandate_company(_params = %{"q" => search_text}) do
    search_text = parse_string(search_text)

    suggestions =
      MandateCompany
      |> filter_by_mandate_company_name(search_text)
      |> order_by(:mandate_company_name)
      |> limit(50)
      |> Repo.all()

    suggestions_list =
      suggestions
      |> Enum.map(fn mandate_company ->
        create_mandate_company_map(mandate_company)
      end)

    {:ok, suggestions_list}
  end

  def admin_search_mandate_company(_params), do: {:error, "Please provide a query param"}

  def create_mandate_company_map(nil), do: nil

  def create_mandate_company_map(mandate_company) do
    %{
      id: mandate_company.id,
      mandate_company_name: mandate_company.mandate_company_name,
      inserted_at: mandate_company.inserted_at,
      updated_at: mandate_company.updated_at
    }
  end

  def fetch_and_parse_mandate_company(nil), do: nil

  def fetch_and_parse_mandate_company(id) do
    fetch_mandate_company(id)
    |> create_mandate_company_map()
  end

  ## Private APIs
  defp get_paginated_results(page_no, limit, mandate_company_name) do
    offset = (page_no - 1) * limit

    mandate_companies_list =
      MandateCompany
      |> filter_by_mandate_company_name(mandate_company_name)
      |> order_by(desc: :updated_at)
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()
      |> Enum.map(fn mandate_company ->
        create_mandate_company_map(mandate_company)
      end)

    %{
      "mandate_companies" => mandate_companies_list,
      "next_page_exists" => Enum.count(mandate_companies_list) == limit,
      "next_page_query_params" => "p=#{page_no + 1}"
    }
  end

  defp filter_by_mandate_company_name(query, mandate_company_name) when mandate_company_name in ["", nil], do: query

  defp filter_by_mandate_company_name(query, mandate_company_name) when is_binary(mandate_company_name) do
    mandate_company_name = "%" <> mandate_company_name <> "%"

    query
    |> where([mc], ilike(mc.mandate_company_name, ^mandate_company_name))
  end

  defp filter_by_mandate_company_name(query, _mandate_company_name), do: query

  defp parse_string(mandate_company_name) when mandate_company_name in ["", nil], do: nil
  defp parse_string(mandate_company_name), do: String.trim(mandate_company_name) |> String.downcase()
end
