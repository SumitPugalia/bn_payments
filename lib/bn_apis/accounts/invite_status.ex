defmodule BnApis.Accounts.InviteStatus do
  use Ecto.Schema
  import Ecto.Changeset

  @new %{id: 1, name: "New"}
  @accepted %{id: 2, name: "Accepted/Joined successfully"}
  @cancelled %{id: 3, name: "Cancelled"}
  @expired %{id: 4, name: "Expired/Inactive"}
  @tried %{id: 5, name: "Tried/OTP generated"}
  @otp_verified %{id: 6, name: "OTP verified"}

  @primary_key false
  schema "brokers_invites_statuses" do
    field :id, :integer, primary_key: true
    field :name, :string

    timestamps()
  end

  def seed_data do
    [
      @new,
      @accepted,
      @cancelled,
      @expired,
      @tried,
      @otp_verified
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

  def new do
    @new
  end

  def accepted do
    @accepted
  end

  def cancelled do
    @cancelled
  end

  def expired do
    @expired
  end

  def tried do
    @tried
  end

  def otp_verified do
    @otp_verified
  end

  def get_by_id(id) do
    seed_data()
    |> Enum.filter(&(&1.id == id))
    |> List.first()
  end

  def get_by_name(name) do
    seed_data()
    |> Enum.filter(&(&1.name == name))
    |> List.first()
  end
end
