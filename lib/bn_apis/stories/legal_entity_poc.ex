defmodule BnApis.Stories.LegalEntityPoc do
  use Ecto.Schema
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Schemas.LegalEntityPoc

  @doc """
    Lists all the POCs.
  """
  def all_legal_entity_poc(params) do
    page_no = params |> Map.get("p", "1") |> String.to_integer()
    limit = params |> Map.get("limit", "30") |> String.to_integer()
    get_paginated_results(page_no, limit)
  end

  @doc """
    List a legal entity POC based on uuid.
  """
  def fetch_legal_entity_poc(uuid) do
    get_legal_entity_poc_from_repo(uuid)
    |> create_legal_entity_poc_map()
  end

  @doc """
    Creates a legal entity POC based on provided params.
  """
  def create(%{
        "poc_name" => poc_name,
        "phone_number" => phone_number,
        "poc_type" => poc_type,
        "email" => email
      }) do
    %LegalEntityPoc{}
    |> LegalEntityPoc.changeset(%{
      poc_name: poc_name,
      phone_number: phone_number,
      poc_type: poc_type,
      email: email
    })
    |> Repo.insert()
    |> case do
      {:ok, legal_entity_poc} ->
        {:ok, create_legal_entity_poc_map(legal_entity_poc)}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
    Updates a legal entity poc based on uuid.
  """
  def update_legal_entity_poc(%{
        "uuid" => uuid,
        "poc_name" => poc_name,
        "phone_number" => phone_number,
        "poc_type" => poc_type,
        "email" => email
      }) do
    legal_entity_poc = get_legal_entity_poc_from_repo(uuid)

    cond do
      is_nil(legal_entity_poc) ->
        {:error, "Legal Entity POC not found"}

      legal_entity_poc ->
        legal_entity_poc
        |> LegalEntityPoc.changeset(%{
          poc_name: poc_name,
          phone_number: phone_number,
          poc_type: poc_type,
          email: email
        })
        |> Repo.update()
    end
  end

  @doc """
    Admin Search API - Returns list of poc based on search text and poc type
  """
  def get_admin_legal_entity_poc_suggestions(query, poc_type) do
    search_text = parse_query(query)

    suggestions =
      search_query_for_legal_entity_poc(search_text, poc_type)
      |> Repo.all()

    suggestions
    |> Enum.map(fn legal_entity_poc ->
      create_legal_entity_poc_map(legal_entity_poc)
    end)
  end

  ### Private APIs

  defp parse_query(nil), do: ""

  defp parse_query(query), do: String.trim(query) |> String.downcase()

  defp create_legal_entity_poc_map(nil), do: nil

  defp create_legal_entity_poc_map(legal_entity_poc) do
    %{
      "uuid" => legal_entity_poc.uuid,
      "id" => legal_entity_poc.id,
      "poc_name" => legal_entity_poc.poc_name,
      "phone_number" => legal_entity_poc.phone_number,
      "poc_type" => legal_entity_poc.poc_type,
      "email" => legal_entity_poc.email
    }
  end

  defp search_query_for_legal_entity_poc(search_text, poc_type) do
    modified_search_text = "%" <> String.trim(search_text) <> "%"

    query =
      if not is_nil(poc_type) do
        LegalEntityPoc |> where([poc], poc.poc_type == ^poc_type)
      else
        LegalEntityPoc
      end

    query =
      if search_text != "" do
        query |> where([poc], ilike(poc.poc_name, ^modified_search_text))
      else
        query
      end

    query
    |> order_by([poc], desc: poc.id, asc: poc.poc_name)
    |> limit(50)
  end

  defp get_legal_entity_poc_from_repo(uuid) do
    LegalEntityPoc
    |> Repo.get_by(uuid: uuid)
  end

  defp get_paginated_results(page_no, limit) do
    offset = (page_no - 1) * limit

    legal_entity_pocs =
      LegalEntityPoc
      |> order_by(desc: :id)
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()

    legal_entity_pocs_map_list =
      legal_entity_pocs
      |> Enum.map(fn legal_entity_poc ->
        create_legal_entity_poc_map(legal_entity_poc)
      end)

    %{
      "legal_entity_pocs" => legal_entity_pocs_map_list,
      "next_page_exists" => Enum.count(legal_entity_pocs) >= limit,
      "next_page_query_params" => "p=#{page_no + 1}"
    }
  end
end
