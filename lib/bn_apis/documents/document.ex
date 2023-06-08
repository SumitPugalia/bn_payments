defmodule BnApis.Documents.Document do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Documents.Document

  schema "documents" do
    field :doc_url, :string
    field :entity_type, :string
    field :entity_id, :integer
    field :doc_name, :string
    field :uploader_id, :integer
    field :uploader_type, :string
    field :is_active, :boolean, default: true
    field :type, :string
    field :priority, :integer

    timestamps()
  end

  @fields [:doc_url, :entity_type, :entity_id, :uploader_id, :is_active, :uploader_type, :doc_name, :type, :priority]

  @doc false
  def changeset(document, attrs) do
    document
    |> cast(attrs, @fields)
    |> validate_required(@fields)
  end

  def upload(attrs) do
    %Document{}
    |> Document.changeset(attrs)
    |> Repo.insert()
  end

  def update(document, attrs) do
    document
    |> Document.changeset(attrs)
    |> Repo.update()
  end

  def remove(doc) do
    ch = %{"is_active" => false}
    doc |> Document.changeset(ch) |> Repo.update()
  end

  def remove_document(id, entity_id, entity_type) do
    doc = Document |> Repo.get_by(id: id, entity_type: entity_type, is_active: true)

    case doc do
      nil ->
        {docs, _number_of_documents} = Document.get_document(entity_id, entity_type, true)
        {:ok, %{message: "document not found", is_image_removed: false, uploaded_docs: docs}}

      doc ->
        removed_doc = Document.remove(doc)
        {docs, _number_of_documents} = Document.get_document(entity_id, entity_type, true)

        case removed_doc do
          {:ok, _removed_doc} ->
            {:ok, %{message: "removed successfully", is_image_removed: true, uploaded_docs: docs}}

          {:error, _msg} ->
            {:ok, %{message: "could not remove", is_image_removed: false, uploaded_docs: docs}}
        end
    end
  end

  def upload_document(documents, user_id, entity_type, uploader) do
    documents
    |> Enum.map(fn attr ->
      attr =
        attr
        |> Map.merge(%{
          "uploader_type" => uploader,
          "uploader_id" => user_id,
          "entity_type" => entity_type
        })

      create_or_update_document(attr)
    end)
  end

  def create_or_update_document(params) do
    entity_id = if is_binary(params["entity_id"]), do: String.to_integer(params["entity_id"]), else: params["entity_id"]
    priority = if is_binary(params["priority"]), do: String.to_integer(params["priority"]), else: params["priority"]

    if(not is_nil(params["doc_id"])) do
      doc_id = if is_binary(params["doc_id"]), do: String.to_integer(params["doc_id"]), else: params["doc_id"]

      doc = Document |> Repo.get_by(entity_id: entity_id, id: doc_id, entity_type: params["entity_type"], is_active: true)

      if(is_nil(doc)) do
        Document.upload(params)
      else
        if priority != doc.priority, do: doc |> Document.update(%{"priority" => priority}), else: nil
      end
    else
      Document.upload(params)
    end
  end

  def get_document(entity_id, entity_type, is_active \\ true) do
    query =
      Document
      |> where([d], d.entity_id == ^entity_id)
      |> where([d], d.entity_type == ^entity_type)

    query =
      if not is_nil(is_active) do
        is_active = if is_active |> is_binary(), do: is_active == "true", else: is_active
        query |> where([d], d.is_active == ^is_active)
      else
        query
      end

    documents =
      query
      |> select([d], %{
        doc_id: d.id,
        doc_url: d.doc_url,
        entity_type: d.entity_type,
        entity_id: d.entity_id,
        doc_name: d.doc_name,
        uploader_id: d.uploader_id,
        uploader_type: d.uploader_type,
        is_active: d.is_active,
        type: d.type,
        priority: d.priority
      })
      |> order_by([d], asc: d.priority)
      |> Repo.all()

    total_count =
      query
      |> Repo.aggregate(:count, :id)

    {documents, total_count}
  end
end
