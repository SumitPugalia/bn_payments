defmodule BnApis.Rewards.StoryTier do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false

  alias BnApis.Repo
  alias BnApis.Stories.Story
  alias BnApis.Rewards.StoryTier
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Rewards.StoryTierPlanMapping

  schema "story_tiers" do
    field :amount, :float
    field :name, :string
    field :is_default, :boolean, default: false

    belongs_to(:employee_credential, EmployeeCredential)
    has_many :stories, Story
    timestamps()

    has_many(:story_tier_plan_mapping, StoryTierPlanMapping,
      foreign_key: :story_tier_id,
      on_delete: :delete_all,
      on_replace: :delete
    )
  end

  @required [:amount, :name, :employee_credential_id, :is_default]
  @optional []

  @doc false
  def changeset(story_tier, attrs) do
    story_tier
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:employee_credential_id)
    |> unique_constraint(:amount)
  end

  def create_story_tier(amount, name, is_default, employee_credential_id) do
    changeset =
      StoryTier.changeset(%StoryTier{}, %{
        amount: amount,
        name: name,
        is_default: is_default,
        employee_credential_id: employee_credential_id
      })

    Repo.insert(changeset)
  end

  def get_tier_data(tier) do
    %{
      id: tier.id,
      amount: tier.amount,
      name: tier.name,
      is_default: tier.is_default
    }
  end

  def get_data() do
    StoryTier
    |> preload(:employee_credential)
    |> Repo.all()
    |> Enum.map(fn str ->
      %{
        id: str.id,
        amount: str.amount,
        name: str.name,
        is_default: str.is_default,
        inserted_at: str.inserted_at,
        created_by: %{
          id: str.employee_credential.id,
          name: str.employee_credential.name,
          phone_number: str.employee_credential.phone_number
        }
      }
    end)
  end
end
