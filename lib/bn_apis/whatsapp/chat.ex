defmodule BnApis.Whatsapp.Chat do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Whatsapp.Chat

  schema "whatsapp_chats" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :phone_number, :string
    field :post_module, :string
    field :post_id, :integer
    field :chat_text, :string
    field :created_by_id, :integer

    timestamps()
  end

  @fields [:phone_number, :uuid, :post_module, :post_id, :chat_text, :created_by_id]
  @required_fields [:phone_number, :post_module, :post_id, :chat_text, :created_by_id]

  def changeset(whatsapp_chat, attrs \\ %{}) do
    whatsapp_chat
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:created_by_id)
  end

  @doc """
  1. Create a new record with the given params if it does not exist
  2. Updates in case record exists
  """
  def create_or_update_chat(params) do
    # result = case fetch_chat(params["phone_number"], params["chat_text"]) do
    #   nil -> %Chat{}
    #   chat -> chat
    # end
    # for now it is creating only
    %Chat{}
    |> Chat.changeset(params)
    |> Repo.insert_or_update()
  end

  @doc """
  1. Fetches chat from phone number and text
  """
  def fetch_chat(phone_number, chat_text) do
    Chat
    |> where([c], c.phone_number == ^phone_number and c.md5_hash == ^chat_text)
    |> Repo.one()
  end

  def create_whatsapp_chat_entry(params, post_module, post_id) do
    params =
      params
      |> Map.merge(%{
        "post_module" => post_module,
        "post_id" => post_id
      })

    create_or_update_chat(params)
  end
end
