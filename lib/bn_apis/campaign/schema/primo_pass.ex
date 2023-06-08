defmodule BnApis.Campaign.Schema.PrimoPass do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  @required ~w(broker_id payload status phone_number email)a
  @fields ~w(pass_data)a ++ @required

  schema "track_primo_pass" do
    field :broker_id, :integer
    field :phone_number, :string
    field :email, :string
    field :payload, :map
    field :pass_data, :map
    field :status, Ecto.Enum, values: [:unverified, :verified]

    timestamps()
  end

  def new(params), do: changeset(%__MODULE__{}, params)

  def changeset(struct, params) do
    struct
    |> cast(params, @fields)
    |> validate_required(@required)
    |> foreign_key_constraint(:broker_id)
  end

  def get_pass(phone_number, email) do
    __MODULE__
    |> where([p], p.phone_number == ^phone_number or p.email == ^email)
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Repo.one()
  end
end
