defmodule BnApis.Accounts.BlockedUser do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Helpers.Time
  alias BnApis.Accounts.BlockedUser

  # in days
  @default_blocking_time 15

  schema "blocked_users" do
    field :blocker, :id
    field :blockee, :id
    field :blocked, :boolean
    field :expires_on, :naive_datetime

    timestamps()
  end

  @fields [:blocked, :blocker, :blockee, :expires_on]
  @required_fields @fields ++ []

  @doc false
  def changeset(credential, attrs \\ %{}) do
    credential
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:blockee)
    |> foreign_key_constraint(:blocker)
  end

  def fetch_blocked_users(user_id) do
    BlockedUser
    |> where(
      [bu],
      (bu.blocker == ^user_id or bu.blockee == ^user_id) and
        bu.blocked == true and
        fragment("? >= timezone('utc', NOW())", bu.expires_on)
    )
    |> select([bu], %{
      blockee: bu.blockee,
      blocker: bu.blocker
    })
    |> Repo.all()
    |> Enum.reduce([], fn x, acc -> acc ++ ([x[:blockee], x[:blocker]] -- [user_id]) end)
    |> Enum.uniq()
  end

  def block(blocker, blockee) do
    changes = %{
      "blocker" => blocker,
      "blockee" => blockee,
      "blocked" => true,
      "expires_on" => Time.set_expiry_time(@default_blocking_time)
    }

    case fetch_blocking_combination(blocker, blockee) do
      nil -> %BlockedUser{}
      result -> result
    end
    |> BlockedUser.changeset(changes)
    |> Repo.insert_or_update()
  end

  def unblock(blocker, blockee) do
    changes = %{
      "blocked" => false
    }

    result = fetch_blocking_combination(blocker, blockee)

    unless result |> is_nil() do
      result |> BlockedUser.changeset(changes) |> Repo.update()
    else
      {:error, "no combination found"}
    end
  end

  def fetch_blocking_combination(blocker, blockee) do
    BlockedUser
    |> where(
      [bu],
      bu.blocker == ^blocker and bu.blockee == ^blockee
    )
    |> Repo.one()
  end

  def is_blocked?(blocker, blockee) do
    result = fetch_blocking_combination(blocker, blockee)

    case result do
      nil -> false
      _ -> result.blocked and NaiveDateTime.compare(result.expires_on, NaiveDateTime.utc_now()) == :gt
    end
  end
end
