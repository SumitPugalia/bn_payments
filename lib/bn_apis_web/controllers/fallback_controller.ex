defmodule BnApisWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use BnApisWeb, :controller
  alias BnApis.Helpers.ErrorMapper

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(BnApisWeb.ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(BnApisWeb.ErrorView)
    |> render(:"404")
  end

  def call(conn, {:error, _message} = error) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(ErrorMapper.format(error))
  end

  def call(conn, {:otp_error, message}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(message)
  end

  def call(conn, {:qr_code_error, message}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(message)
  end

  def call(conn, {:unauthorized, message}) do
    conn
    |> put_status(:unauthorized)
    |> json(message)
  end
end
