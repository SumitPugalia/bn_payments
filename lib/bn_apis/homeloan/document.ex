defmodule BnApis.Homeloan.Document do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Homeloan.Document
  alias BnApis.Homeloan.Lead
  alias BnApis.Accounts.ProfileType
  alias BnApis.Helpers.S3Helper
  alias BnApis.Homeloan.DocType
  alias BnApis.Helpers.AuditedRepo
  alias BnApis.Helpers.Time

  schema "homeloan_documents" do
    field :doc_url, :string
    field :doc_name, :string
    field :doc_type, :integer
    field :uploader_id, :integer
    field :uploader_type, :string
    field :access_to_cp, :boolean
    field :active, :boolean, default: true
    field :mime_type, :string
    field :lead_status_id, :integer

    belongs_to :homeloan_lead, Lead

    timestamps()
  end

  @required [:doc_url, :homeloan_lead_id, :access_to_cp, :doc_name, :doc_type]
  @optional [:uploader_id, :active, :uploader_type, :mime_type, :lead_status_id]

  @homeloan_documents_schema_name "homeloan_documents"

  def homeloan_documents_schema_name do
    @homeloan_documents_schema_name
  end

  @doc false
  def changeset(lead, attrs) do
    lead
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:homeloan_lead_id)
  end

  def save_doc(
        params = %{"homeloan_lead_id" => homeloan_lead_id},
        session_data,
        uploader_type,
        user_map
      ) do
    access_to_cp =
      if uploader_type === ProfileType.broker().name do
        true
      else
        params["access_to_cp"]
      end

    lead = Lead.get_homeloan_lead(homeloan_lead_id) |> Repo.preload(:latest_lead_status)
    latest_status_id = lead.latest_lead_status.status_id

    Document.changeset(%Document{}, %{
      doc_url: params["protected_signed_key"],
      homeloan_lead_id: homeloan_lead_id,
      access_to_cp: access_to_cp,
      uploader_id: session_data["user_id"],
      doc_type: params["doc_type"],
      doc_name: params["doc_name"],
      uploader_type: uploader_type,
      mime_type: params["mime_type"],
      lead_status_id: latest_status_id
    })
    |> AuditedRepo.insert(user_map)
  end

  def delete_document(params, user_type, user_map) do
    case Repo.get_by(Document, id: params["doc_id"]) do
      nil ->
        {:error, :not_found}

      doc ->
        if doc.uploader_type === user_type do
          doc |> changeset(%{active: false}) |> AuditedRepo.update(user_map)
        else
          {:error, "Document cannot be deleted"}
        end
    end
  end

  def get_documents(params, user_type) do
    homeloan_lead_id = params["lead_id"]
    homeloan_lead_id = if is_binary(homeloan_lead_id), do: String.to_integer(homeloan_lead_id), else: homeloan_lead_id

    cond do
      user_type == ProfileType.broker().name ->
        broker_active_docs =
          Document
          |> where([doc], doc.homeloan_lead_id == ^homeloan_lead_id and doc.active == true and doc.access_to_cp == true)
          |> Repo.all()
          |> Enum.map(fn document ->
            create_doc_response(document)
          end)

        {:ok, %{documents: %{active_docs: broker_active_docs}}}

      user_type == ProfileType.employee().name ->
        active_docs =
          Document
          |> where([doc], doc.homeloan_lead_id == ^homeloan_lead_id and doc.active == true)
          |> Repo.all()
          |> Enum.map(fn document ->
            create_doc_response(document)
          end)

        deleted_docs_by_broker =
          Document
          |> where(
            [doc],
            doc.homeloan_lead_id == ^homeloan_lead_id and doc.active == false and doc.uploader_type == "Broker"
          )
          |> Repo.all()
          |> Enum.map(fn document ->
            create_doc_response(document)
          end)

        {:ok, %{documents: %{active_docs: active_docs, deleted_docs_by_broker: deleted_docs_by_broker}}}
    end
  end

  def create_doc_response(document) do
    imgix_doc_url = S3Helper.get_imgix_url(document.doc_url)

    %{
      doc_id: document.id,
      doc_url: imgix_doc_url,
      doc_type: document.doc_type,
      doc_name: document.doc_name,
      uploader_type: document.uploader_type,
      access_to_cp: document.access_to_cp,
      mime_type: document.mime_type,
      allow_delete: if(document.uploader_type == ProfileType.employee().name, do: false, else: true)
    }
  end

  def fetch_lead_docs(lead, for_admin, is_employee_view) do
    lead.homeloan_documents
    |> Enum.filter(fn x -> filter_docs(for_admin, x) end)
    |> Enum.map(fn d ->
      imgix_doc_url = S3Helper.get_imgix_url(d.doc_url)
      doc_type_details = DocType.get_details_by_id(d.doc_type)
      allow_delete = if is_employee_view, do: false, else: check_allow_delete_based_on_uploader(d.uploader_type)

      %{
        :id => d.id,
        :doc_url => imgix_doc_url,
        :doc_name => d.doc_name,
        :doc_type => d.doc_type,
        :doc_type_name => if(is_nil(doc_type_details), do: nil, else: doc_type_details.name),
        :access_to_cp => d.access_to_cp,
        :mime_type => d.mime_type,
        :uploader_type => d.uploader_type,
        :allow_delete => allow_delete,
        :inserted_at => d.inserted_at |> Time.naive_to_epoch_in_sec(),
        :homeloan_lead_id => d.homeloan_lead_id,
        :doc_entity_type => homeloan_documents_schema_name()
      }
    end)
  end

  defp check_allow_delete_based_on_uploader(uploader_type) do
    if uploader_type == ProfileType.employee().name, do: false, else: true
  end

  defp filter_docs(true, x) do
    x.active == true
  end

  defp filter_docs(false, x) do
    x.active == true and x.access_to_cp == true
  end
end
