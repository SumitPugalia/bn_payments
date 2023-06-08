defmodule BnApis.Rewards.StoryTransaction do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false

  alias BnApis.Rewards.StoryTransaction
  alias BnApis.Repo
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Helpers.AuditedRepo
  alias BnApis.Stories.{Story, LegalEntity}

  schema "story_transactions" do
    field(:amount, :float)
    field(:remark, :string)
    field(:proof_url, :string)
    field(:active, :boolean, default: true)

    belongs_to(:story, Story)
    belongs_to(:employee_credential, EmployeeCredential)
    belongs_to(:legal_entity, LegalEntity)
    timestamps()
  end

  @required [:story_id, :employee_credential_id, :amount, :remark]
  @optional [:proof_url, :legal_entity_id, :active]

  @doc false
  def changeset(story_transaction, attrs) do
    story_transaction
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:employee_credential_id)
    |> foreign_key_constraint(:story_id)
    |> foreign_key_constraint(:legal_entity_id)
  end

  def create_story_transaction!(amount, employee_credential_id, story_id, remark, proof_url, legal_entity_id, user_map) do
    changeset =
      StoryTransaction.changeset(%StoryTransaction{}, %{
        amount: amount,
        employee_credential_id: employee_credential_id,
        story_id: story_id,
        remark: remark,
        proof_url: proof_url,
        legal_entity_id: legal_entity_id
      })

    story = Repo.get(Story, story_id)

    with {:ok, st} <- AuditedRepo.insert(changeset, user_map),
         balances <- Story.get_story_balances(story) do
      maybe_disable_sv_rewards_on_negative_credits(story_id, balances, user_map)
      {:ok, st}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def get_story_transactions(story_id) do
    StoryTransaction
    |> where([st], st.story_id == ^story_id and st.active == true)
    |> order_by(desc: :inserted_at)
    |> preload(:employee_credential)
    |> Repo.all()
    |> Enum.map(fn str ->
      %{
        id: str.id,
        amount: str.amount,
        inserted_at: str.inserted_at,
        remark: str.remark,
        proof_url: str.proof_url,
        legal_entity_id: str.legal_entity_id,
        inserted_by: %{
          name: str.employee_credential.name,
          id: str.employee_credential.id,
          phone_number: str.employee_credential.phone_number
        }
      }
    end)
  end

  def update_legal_entity_id_for_story_transaction(story_transaction, legal_entity_id, user_map) do
    story_transaction
    |> changeset(%{
      legal_entity_id: legal_entity_id
    })
    |> AuditedRepo.update(user_map)
  end

  defp maybe_disable_sv_rewards_on_negative_credits(story_id, balances, user_map) do
    story = Story |> Repo.get(story_id)

    if balances[:total_credits_amount] - balances[:total_debits_amount] - balances[:total_pending_amount] -
         balances[:total_approved_amount] < balances[:story_tier_amount] do
      story |> cast(%{"is_rewards_enabled" => false}, [:is_rewards_enabled]) |> AuditedRepo.update(user_map)
      story |> cast(%{"is_cab_booking_enabled" => false}, [:is_cab_booking_enabled]) |> AuditedRepo.update(user_map)
    end
  end
end
