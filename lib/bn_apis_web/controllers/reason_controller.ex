defmodule BnApisWeb.ReasonController do
  use BnApisWeb, :controller

  alias BnApis.Reasons
  alias BnApis.Reasons.Reason

  action_fallback BnApisWeb.FallbackController

  def index(conn, _params) do
    reasons_types = Reasons.list_reasons_types()

    data =
      reasons_types
      |> Enum.reduce(%{}, fn reason, acc ->
        acc
        |> Map.merge(%{
          "#{reason.reason_key}_reasons": reason.reasons |> Enum.map(fn rs -> %{id: rs.id, name: rs.name} end)
        })
      end)

    conn
    |> put_status(:ok)
    |> json(data)
  end

  def create(conn, %{"reason" => reason_params}) do
    with {:ok, %Reason{} = reason} <- Reasons.create_reason(reason_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.reason_path(conn, :show, reason))
      |> render("show.json", reason: reason)
    end
  end

  def show(conn, %{"id" => id}) do
    reason = Reasons.get_reason!(id)
    render(conn, "show.json", reason: reason)
  end

  def update(conn, %{"id" => id, "reason" => reason_params}) do
    reason = Reasons.get_reason!(id)

    with {:ok, %Reason{} = reason} <- Reasons.update_reason(reason, reason_params) do
      render(conn, "show.json", reason: reason)
    end
  end

  def delete(conn, %{"id" => id}) do
    reason = Reasons.get_reason!(id)

    with {:ok, %Reason{}} <- Reasons.delete_reason(reason) do
      send_resp(conn, :no_content, "")
    end
  end
end
