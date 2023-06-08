defmodule BnApis.Transactions.TransactionData do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Transactions.{District, DocType, TransactionData, Status}
  alias BnApis.Buildings.Building
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Helpers.Time
  alias BnApis.Repo

  schema "transactions_data" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :amount, :decimal
    field :doc_html, :string
    field :doc_number, :integer
    field :registration_date, :naive_datetime
    field :sro_id, :string
    field :flat_number, :integer
    field :floor_number, :integer
    field :rblDocType, :integer
    field :year, :integer
    field :invalid_reason, :string

    belongs_to :doc_type, DocType
    belongs_to :district, District
    belongs_to :building, Building

    belongs_to :status, Status
    belongs_to :assignee, EmployeeCredential

    timestamps()
  end

  @required [:doc_html, :doc_number, :sro_id, :doc_type_id, :district_id, :rblDocType]
  @fields @required ++
            [
              :uuid,
              :building_id,
              :flat_number,
              :floor_number,
              :registration_date,
              :amount,
              :status_id,
              :assignee_id,
              :year,
              :invalid_reason
            ]

  @doc false
  def changeset(transaction_data, attrs) do
    transaction_data
    |> cast(attrs, @fields)
    |> validate_required(@required)
    |> unique_constraint(:sro_id, name: :sro_doc_year_unique_constraint, message: "Doc already present!")
    |> unique_constraint(:assignee_id,
      name: :td_in_process_uniq_index,
      message: "A user can have only one document as in-process!"
    )
  end

  def fetch_data_from_sro(sro_id) do
    TransactionData
    |> where(sro_id: ^sro_id)
    |> order_by(desc: :doc_number)
    |> Repo.all()
  end

  def change_status(transaction_data, status_id, user_id) do
    transaction_data
    |> change(assignee_id: user_id)
    |> change(status_id: status_id)
  end

  def fetch_transaction_data(user_id, status_id) do
    TransactionData
    |> where(assignee_id: ^user_id)
    |> where(status_id: ^status_id)
  end

  def fetch_random_unprocessed_transaction(true) do
    TransactionData
    |> where([td], is_nil(td.assignee_id) and is_nil(td.status_id) and td.doc_type_id == 1)
    |> where([td], fragment("random() < 0.01"))
    |> order_by(desc: :year)
    |> limit(1)
  end

  def fetch_random_unprocessed_transaction(false) do
    TransactionData
    |> where([td], is_nil(td.assignee_id) and is_nil(td.status_id))
    |> where([td], fragment("random() < 0.01"))
    |> order_by(desc: :year)
    |> limit(1)
  end

  def mark_as_inactive(transaction_data, user_id, invalid_reason) do
    invalid_id = Status.invalid().id

    transaction_data
    |> change(assignee_id: user_id)
    |> change(status_id: invalid_id)
    |> change(invalid_reason: invalid_reason)
  end

  def assign_and_mark_in_process(transaction_data, user_id) do
    in_process_id = Status.in_process().id

    params = %{
      assignee_id: user_id,
      status_id: in_process_id
    }

    transaction_data
    |> changeset(params)
  end

  def total_documents_processed_count(user_id) do
    processed_id = Status.processed().id

    TransactionData
    |> where([td], td.assignee_id == ^user_id and td.status_id == ^processed_id)
    |> BnApis.Repo.aggregate(:count, :id)
  end

  def today_documents_processed_count(user_id) do
    processed_id = Status.processed().id
    today = Time.get_start_of_day()

    TransactionData
    |> where([td], td.assignee_id == ^user_id and td.status_id == ^processed_id and td.updated_at >= ^today)
    |> BnApis.Repo.aggregate(:count, :id)
  end

  def year_sro_id_query(year, sro_id, document_id) do
    TransactionData
    |> where([td], td.year == ^year and td.sro_id == ^sro_id and td.doc_number == ^document_id)
  end
end
