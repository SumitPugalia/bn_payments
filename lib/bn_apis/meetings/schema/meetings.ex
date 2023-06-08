defmodule BnApis.Meetings.Schema.Meetings do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Organizations.Broker
  alias BnApis.Accounts.EmployeeCredential

  schema "meetings" do
    field(:latitude, :float)
    field(:longitude, :float)
    field(:notes, :string)
    field(:address, :string)
    field(:active, :boolean, default: false)

    belongs_to :broker, Broker
    belongs_to :employee_credentials, EmployeeCredential

    timestamps()
  end

  @required [:latitude, :longitude, :broker_id, :employee_credentials_id, :address, :active]
  @optional [:notes]

  @doc false
  def changeset(meeting, attrs) do
    meeting
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:employee_credentials_id)
    |> foreign_key_constraint(:broker_id)
  end
end
