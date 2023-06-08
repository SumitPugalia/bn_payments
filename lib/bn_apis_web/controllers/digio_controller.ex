defmodule BnApisWeb.DigioController do
  use BnApisWeb, :controller
  require Logger

  alias BnApis.Digio.API, as: DigioApi

  def process_webhook(conn, params) do
    DigioApi.handle_webhook(params)
    conn |> put_status(:ok) |> json(%{message: "Request processed"})
  end
end
