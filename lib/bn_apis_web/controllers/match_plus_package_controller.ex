defmodule BnApisWeb.MatchPlusPackageController do
  use BnApisWeb, :controller

  alias BnApis.Orders.MatchPlusPackage

  action_fallback BnApisWeb.FallbackController

  def all_match_plus_data(conn, params) do
    conn
    |> put_status(:ok)
    |> json(MatchPlusPackage.all_match_plus_data(params))
  end

  def show(conn, %{"uuid" => uuid}) do
    match_plus_package = MatchPlusPackage.fetch_match_plus_data_by_uuid(uuid)

    if is_nil(match_plus_package) do
      conn
      |> put_status(:not_found)
      |> json(%{message: "Match Plus Package does not exist"})
    else
      conn
      |> put_status(:ok)
      |> json(match_plus_package)
    end
  end

  def create_match_plus_record(conn, params) do
    with {:ok, match_plus_package} <- MatchPlusPackage.create(params) do
      conn
      |> put_status(:ok)
      |> json(match_plus_package)
    end
  end

  def update_match_plus_record(conn, params) do
    with {:ok, _match_plus_package} <- MatchPlusPackage.update_match_plus_record(params) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Successfully updated Match Plus Package record"})
    end
  end
end
