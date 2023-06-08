defmodule BnApisWeb.ChangesetView do
  use BnApisWeb, :view

  @doc """
  Traverses and translates changeset errors.

  See `Ecto.Changeset.traverse_errors/2` and
  `BnApisWeb.ErrorHelpers.translate_error/1` for more details.
  """
  def translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end

  def render("error.json", %{changeset: changeset}) do
    # When encoded, the changeset returns its errors
    # as a JSON object. So we just pass it forward.
    %{message: translate_errors(changeset) |> parse()}
  end

  def parse(map, prefix \\ "") do
    Enum.reduce(map, "", &(parse_map_keys(&1, prefix) |> append_result(&2, " | ")))
  end

  defp parse_map_keys({key, value}, prefix) when is_list(value) do
    parse_list(value, get_key(key, prefix))
  end

  defp parse_map_keys({key, value}, prefix) when is_map(value) do
    parse(value, get_key(key, prefix))
  end

  defp parse_map_keys({key, "$" <> value}, prefix), do: "#{get_key(key, prefix)} #{value}"
  defp parse_map_keys({key, value}, prefix), do: "#{get_key(key, prefix)} #{value}"

  defp parse_list(list, prefix) do
    Enum.reduce(list, "", fn
      el, acc when is_map(el) ->
        parse(el, prefix) |> append_result(acc, ",")

      "$" <> el, acc ->
        append_result(el, acc, ",")

      el, acc ->
        append_result(prefix <> " " <> el, acc, ",")
    end)
  end

  defp get_key(key, _) when is_atom(key) and not is_nil(key), do: String.capitalize(Atom.to_string(key) |> String.replace("_id", "") |> String.replace("_", " "))
  defp get_key(key, ""), do: stringify(key)
  defp get_key(key, prefix), do: prefix <> "->" <> stringify(key)

  defp stringify(value) when is_bitstring(value), do: value
  defp stringify(value), do: inspect(value)

  defp append_result(result, "", _seperator), do: result
  defp append_result(result, acc, seperator), do: acc <> seperator <> result
end
