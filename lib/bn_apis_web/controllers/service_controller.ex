defmodule BnApisWeb.ServiceController do
  use BnApisWeb, :controller

  def health_check(conn, _params) do
    with({:ok, _} <- database_check()) do
      conn |> put_status(:ok) |> json(%{message: "Service Working properly"})
    else
      {:error, errors} -> conn |> put_status(:unprocessable_entity) |> json(%{message: errors})
      _ -> conn |> put_status(:unprocessable_entity) |> json(%{message: "DB connection failed"})
    end
  end

  def database_check do
    BnApis.Repo.query("select * from whitelisted_numbers limit 1")
  end
end
