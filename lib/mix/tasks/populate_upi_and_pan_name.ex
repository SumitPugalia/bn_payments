defmodule Mix.Tasks.PopulateUpiAndPanName do
  import Ecto.Query
  import Ecto.Changeset

  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Organizations.Broker
  alias BnApis.Accounts.Credential
  alias BnApis.Accounts
  alias BnApis.Signzy.API

  def run(_) do
    Mix.Task.run("app.start", [])
    update_upi_name()
    update_pan_name()
  end

  def update_upi_name() do
    Credential
    |> where([c], not is_nil(c.upi_name) and not is_nil(c.upi_id))
    |> Repo.all()
    |> Enum.each(fn cred ->
      upi_id = cred.upi_id |> String.downcase()
      {status, upi_name} = Accounts.validate_upi(upi_id)

      if status == true do
        cred |> cast(%{"upi_name" => upi_name}, [:upi_name]) |> Repo.update!()
      end
    end)
  end

  def update_pan_name() do
    Broker
    |> where([b], not is_nil(b.pan_name) and not is_nil(b.pan))
    |> Repo.all()
    |> Enum.each(fn broker ->
      pan = broker.pan |> String.downcase()
      pan_image_url = Broker.parse_broker_pan_image(broker.pan_image)

      API.validate_pan_details(pan, pan_image_url, String.trim(broker.name))
      |> case do
        {:ok, true, pan_name} ->
          broker |> cast(%{"pan_name" => pan_name}, [:pan_name]) |> Repo.update!()

        {:ok, false, pan_name} ->
          broker |> cast(%{"pan_name" => pan_name}, [:pan_name]) |> Repo.update!()

        _ ->
          nil
      end
    end)
  end
end
