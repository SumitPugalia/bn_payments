defmodule BnApisWeb.V2.RewardsController do
  use BnApisWeb, :controller

  alias BnApis.Rewards

  action_fallback(BnApisWeb.FallbackController)

  def get_leads(conn, params) do
    with {:ok, data} <- Rewards.get_leads(params, conn.assigns[:user], true) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end
end
