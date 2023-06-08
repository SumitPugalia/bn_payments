defmodule BnApis.Accounts.Status do
  use Ecto.Schema
  import Ecto.Changeset

  @active %{id: 1, name: "Active"}
  @inactive %{id: 2, name: "Inactive"}
  @suspended %{id: 3, name: "Suspended"}
  @new %{id: 4, name: "New"}

  @primary_key false
  schema "credentials_statuses" do
    field :id, :integer, primary_key: true
    field :name, :string

    timestamps()
  end

  def seed_data do
    [
      @active,
      @inactive,
      @suspended,
      @new
    ]
  end

  def changeset(status, params) do
    status
    |> cast(params, [:id, :name])
    |> validate_required([:id, :name])
    |> unique_constraint(:name)
  end

  def changeset(params) do
    %__MODULE__{}
    |> changeset(params)
  end

  def active do
    @active
  end

  def inactive do
    @inactive
  end

  def suspended do
    @suspended
  end

  def new do
    @new
  end
end
