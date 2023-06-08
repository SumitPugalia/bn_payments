defmodule BnApis.Helpers.FormHelper do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApisWeb.Helpers.PhoneHelper, as: Phone

  def validate_string(str) do
    not is_nil(str) && String.trim(str) != ""
  end

  def validate_attachment(attachment, allowed_extensions \\ nil)

  def validate_attachment(attachment, _allowed_extensions) when is_nil(attachment) do
    true
  end

  def validate_attachment(attachment, allowed_extensions) do
    extension = Path.extname(attachment) |> String.slice(1..-1)

    errors =
      [
        {validate_string(attachment), "is invalid"},
        {!allowed_extensions || allowed_extensions |> Enum.member?(extension), "file with extension #{extension} not allowed"}
      ]
      |> Enum.filter(fn {flag, _} -> !flag end)
      |> Enum.map(fn {_, error_message} -> error_message end)

    if errors |> List.first() do
      {false, errors}
    else
      true
    end
  end

  def validate_phone_number(changeset, field) do
    case changeset.valid? do
      true ->
        phone_number = get_field(changeset, field)
        country_code = get_field(changeset, :country_code, "+91")

        case Phone.parse_phone_number(country_code, phone_number) do
          {:ok, phone_number, _} ->
            changeset |> change(phone_number: phone_number)

          _ ->
            add_error(changeset, :phone_number, "Invalid phone_number")
        end

      _ ->
        changeset
    end
  end

  def validate_email(changeset, field) do
    email = get_field(changeset, field)
    # removes spaces
    email = Regex.replace(~r/\s/, email, "")
    email_regex = Regex.compile!("^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$")

    case String.match?(email, email_regex) do
      true -> changeset
      _ -> add_error(changeset, :email, "Invalid email")
    end
  end

  # either of visited_by_id or phone number is required
  def validate_site_visit(changeset) do
    {visited_by_id, broker_phone_number} = {get_field(changeset, :visited_by_id), get_field(changeset, :broker_phone_number)}

    if is_nil(visited_by_id) and is_nil(broker_phone_number) do
      add_error(changeset, :broker_phone_number, "Either of visited_by_id or valid phone_number is required!!")
    else
      changeset
    end
  end
end
