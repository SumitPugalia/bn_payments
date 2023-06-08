defmodule BnApis.RemoteConfig.RemoteConfig do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Repo
  alias BnApis.RemoteConfig.RemoteConfig

  schema "remote_config" do
    field :ios_minimum_supported_version, :string
    field :android_minimum_supported_version, :string
    field :app_name, :string
    timestamps()
  end

  @fields [:ios_minimum_supported_version, :android_minimum_supported_version, :app_name]

  @doc false
  def changeset(remote_config, attrs) do
    remote_config
    |> cast(attrs, @fields)
    |> validate_required([:app_name])
    |> unique_constraint(:app_name)
  end

  @doc """
  1. Create a new record with the given params if it does not exist
  2. Updates in case record exists
  """
  def create_or_update_remote_config(params, app_name) do
    remote_config = Repo.get_by(RemoteConfig, app_name: app_name)

    case remote_config do
      nil -> %RemoteConfig{}
      remote_config -> remote_config
    end
    |> RemoteConfig.changeset(params)
    |> Repo.insert_or_update()
  end
end
