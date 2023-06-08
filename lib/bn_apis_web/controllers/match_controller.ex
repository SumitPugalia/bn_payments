defmodule BnApisWeb.MatchController do
  use BnApisWeb, :controller

  alias BnApis.Posts.MatchHelper
  alias BnApis.Posts.RentalMatch
  alias BnApis.Posts.ResaleMatch

  @update_match_status_mandatory_keys ["match_type", "match_id"]

  def update_match_status(conn, params) do
    validations = check_update_status_params(params)

    unless validations["valid"] do
      conn |> put_status(:bad_request) |> json(%{message: validations["errors"]})
    else
      {status, response} =
        cond do
          params["match_type"] |> String.downcase() == "rent" ->
            RentalMatch.update_match_status(params["match_id"], params)

          params["match_type"] |> String.downcase() == "resale" ->
            ResaleMatch.update_match_status(params["match_id"], params)

          true ->
            {:error, "Unprocessable Entity"}
        end

      if status == :ok do
        conn |> put_status(:ok) |> json(%{message: "Successfully Updated"})
      else
        conn |> put_status(:unprocessable_entity) |> json(%{message: inspect(response.errors)})
      end
    end
  end

  def fetch_owner_matches(
        conn,
        params = %{
          "match_type" => _post_type
        }
      ) do
    with {matches, total_count, has_more_matches} <- MatchHelper.fetch_owner_matches(params) do
      conn
      |> put_status(:ok)
      |> json(%{
        matches: matches,
        total_count: total_count,
        has_more_matches: has_more_matches
      })
    end
  end

  def fetch_matches(
        conn,
        params = %{
          "match_type" => _post_type
        }
      ) do
    with {matches, total_count, has_more_matches} <- MatchHelper.fetch_all_matches(params) do
      conn
      |> put_status(:ok)
      |> json(%{
        matches: matches,
        total_count: total_count,
        has_more_matches: has_more_matches
      })
    end
  end

  defp check_update_status_params(params) do
    Enum.reduce(@update_match_status_mandatory_keys, %{"valid" => true, "errors" => []}, fn key, acc ->
      if is_nil(params[key]) do
        acc
        |> put_in(["valid"], false)
        |> put_in(["errors"], acc["errors"] ++ ["#{key} is missing"])
      else
        acc
      end
    end)
  end
end
