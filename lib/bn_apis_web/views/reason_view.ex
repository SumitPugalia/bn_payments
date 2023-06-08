defmodule BnApisWeb.ReasonView do
  use BnApisWeb, :view
  alias BnApisWeb.ReasonView
  alias BnApis.Reasons.ReasonType

  def render("index.json", %{reasons_types: reasons_types}) do
    reasons_types
    |> Enum.reduce(%{}, fn reason, acc ->
      reason_type = ReasonType.get_by_id(reason.id)

      acc
      |> Map.merge(%{"#{reason_type.key}_reasons": render_many(reason.reasons, ReasonView, "reason.json", as: :reason)})
    end)
  end

  def render("show.json", %{reason: reason}) do
    %{data: render_one(reason, ReasonView, "reason.json")}
  end

  def render("reason_type.json", %{reason: reason_type}) do
    %{
      id: reason_type.id,
      name: reason_type.name,
      reasons: render_many(reason_type.reasons, ReasonView, "reason.json", as: :reason)
    }
  end

  def render("reason.json", %{reason: reason}) do
    %{id: reason.id, name: reason.name}
  end
end
