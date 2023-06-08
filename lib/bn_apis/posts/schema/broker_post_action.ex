defmodule BnApis.Posts.Schema.BrokerPostAction do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Organizations.Broker

  @schema_name "broker_post_actions"

  def schema_name(), do: @schema_name

  schema "broker_post_actions" do
    field :post_type, :string
    field :post_uuid, :string
    field :action, Ecto.Enum, values: ~w(call chat)a

    belongs_to :user, Broker

    timestamps()
  end

  @required [
    :post_type,
    :post_uuid,
    :action,
    :user_id
  ]

  @doc false
  def changeset(post_action, attrs \\ %{}) do
    post_action
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> assoc_constraint(:user)
  end
end
