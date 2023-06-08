defmodule BnApis.Helpers.AuditedRepo do
  alias BnApis.Repo
  alias BnApis.Log
  alias BnApis.Stories.Story
  alias BnApis.BookingRewards.Schema.BookingRewardsLead

  @type user_map :: %{required(:user_id) => integer(), required(:user_type) => String.t()}
  @spec insert(Ecto.Changeset.t(), user_map) :: {:ok, any()} | {:error, Ecto.Changeset.t()}
  def insert(changeset, user_map) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:entity, changeset)
    |> Ecto.Multi.run(:log, fn _repo, %{entity: entity} ->
      Log.changeset(%Log{}, create_log_params(user_map, entity, changeset, "insert"))
      |> Repo.insert()
    end)
    |> Repo.transaction()
    |> transform_response
  end

  @spec update(Ecto.Changeset.t(), user_map) :: {:ok, any()} | {:error, Ecto.Changeset.t()}
  def update(changeset, user_map) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:entity, changeset)
    |> Ecto.Multi.run(:log, fn _repo, %{entity: entity} ->
      Log.changeset(%Log{}, create_log_params(user_map, entity, changeset, "update"))
      |> Repo.insert()
    end)
    |> Repo.transaction()
    |> transform_response
  end

  @spec insert_or_update(Ecto.Changeset.t(), user_map) :: {:ok, any()} | {:error, Ecto.Changeset.t()}
  def insert_or_update(changeset, user_map) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert_or_update(:entity, changeset)
    |> Ecto.Multi.run(:log, fn _repo, %{entity: entity} ->
      Log.changeset(%Log{}, create_log_params(user_map, entity, changeset, "insert_or_update"))
      |> Repo.insert()
    end)
    |> Repo.transaction()
    |> transform_response
  end

  @spec delete(any(), user_map) :: {:ok, any()} | {:error, Ecto.Changeset.t()}
  def delete(entity_, user_map) do
    Ecto.Multi.new()
    |> Ecto.Multi.delete(:entity, entity_)
    |> Ecto.Multi.run(:log, fn _repo, %{entity: entity} ->
      Log.changeset(%Log{}, create_log_params(user_map, entity, entity_, "delete"))
      |> Repo.insert()
    end)
    |> Repo.transaction()
    |> transform_response
  end

  def create_log_params(user_map, entity, changeset, action) do
    changes =
      case action do
        "delete" ->
          %{action: "delete"}

        _ ->
          case entity.__meta__.source do
            "stories" -> Story.story_changeset_serializer(changeset)
            "booking_rewards_leads" -> BookingRewardsLead.booking_rewards_lead_changeset_serializer(changeset)
            _ -> serialize(changeset)
          end
      end

    %{
      user_id: user_map[:user_id],
      user_type: user_map[:user_type],
      entity_id: entity.id,
      entity_type: entity.__meta__.source,
      changes: changes
    }
  end

  defp transform_response(response) do
    case response do
      {:ok, %{entity: entity, log: _log}} -> {:ok, entity}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  defp list_serialize(list) do
    Enum.map(list, fn item ->
      cond do
        is_struct(item) -> serialize(item)
        is_list(item) -> list_serialize(item)
        true -> item
      end
    end)
  end

  defp serialize(changeset) do
    Enum.reduce(changeset.changes, %{}, fn {key, value}, map ->
      cond do
        is_struct(value) -> Map.put(map, key, serialize(value))
        is_list(value) -> Map.put(map, key, list_serialize(value))
        true -> Map.put(map, key, value)
      end
    end)
  end
end
