defmodule BnApis.Commercials.CommercialPropertyStatusLog do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Commercials.CommercialPropertyPost
  alias BnApis.Commercials.CommercialPropertyStatusLog
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Helpers.Time

  @draft "DRAFT"

  schema "commercial_property_status_log" do
    field :status_from, :string
    field :status_to, :string
    field :comment, :string
    field :active, :boolean, default: true

    belongs_to(:commercial_property_post, CommercialPropertyPost)
    belongs_to(:created_by, EmployeeCredential)
    timestamps()
  end

  @required [:status_to, :commercial_property_post_id, :created_by_id, :active]
  @optional [:status_from, :comment]

  def changeset(commercial_status_log, attrs) do
    commercial_status_log
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:commercial_property_post_id)
    |> foreign_key_constraint(:created_by_id)
  end

  def create_status_log(attrs) do
    ch = CommercialPropertyStatusLog.changeset(%CommercialPropertyStatusLog{}, attrs)

    if ch.valid? do
      case Repo.insert(ch) do
        {:ok, status_log} -> {:ok, status_log.id}
        {:error, msg} -> {:error, msg}
      end
    else
      {:error, ch}
    end
  end

  def get_comments(post_id) do
    CommercialPropertyStatusLog
    |> join(:inner, [c, e], e in EmployeeCredential, on: c.created_by_id == e.id)
    |> where([c], c.commercial_property_post_id == ^post_id)
    |> where([c], c.status_to == ^@draft and not is_nil(c.comment))
    |> order_by([c], desc: c.inserted_at)
    |> Repo.all()
    |> Repo.preload([:created_by])
    |> Enum.map(fn c ->
      %{
        "status_from" => c.status_from,
        "status_to" => c.status_to,
        "comment" => c.comment,
        "created_at" => Time.naive_to_epoch_in_sec(c.inserted_at),
        "name" => c.created_by.name,
        "phone_number" => c.created_by.phone_number,
        "country_code" => c.created_by.country_code,
        "email" => c.created_by.email,
        "employee_code" => c.created_by.employee_code
      }
    end)
  end
end
