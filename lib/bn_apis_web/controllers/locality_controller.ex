defmodule BnApisWeb.LocalityController do
  use BnApisWeb, :controller

  alias BnApis.Places
  alias BnApis.Places.Locality

  action_fallback(BnApisWeb.FallbackController)

  def index(conn, _params) do
    # Places.list_localities()
    localities = []
    render(conn, "index.json", localities: localities)
  end

  def create(conn, %{"locality" => locality_params}) do
    with {:ok, %Locality{} = locality} <-
           Places.create_locality(locality_params) do
      conn
      |> put_status(:created)
      # |> put_resp_header("location", Routes.locality_path(conn, :show, locality))
      |> render("show.json", locality: locality)
    end
  end

  def show(conn, %{"id" => id}) do
    locality = Places.get_locality!(id)
    render(conn, "show.json", locality: locality)
  end

  def update(conn, %{"id" => id, "locality" => locality_params}) do
    locality = Places.get_locality!(id)

    with {:ok, %Locality{} = locality} <-
           Places.update_locality(locality, locality_params) do
      render(conn, "show.json", locality: locality)
    end
  end

  def delete(conn, %{"id" => id}) do
    locality = Places.get_locality!(id)

    with {:ok, %Locality{}} <- Places.delete_locality(locality) do
      send_resp(conn, :no_content, "")
    end
  end

  def search_localities(conn, %{"q" => search_text}) do
    search_text = search_text |> String.downcase()
    suggestions = Places.get_locality_suggestions(search_text)

    conn
    |> put_status(:ok)
    |> json(%{suggestions: suggestions})
  end
end
