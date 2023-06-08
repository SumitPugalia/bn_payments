defmodule BnApis.Digio.DigioDocs do
  import Ecto.Query, warn: false
  alias BnApis.Repo
  alias BnApis.DigioDocs.Schema.DigioDoc

  def get_doc_details_by(params) do
    where = Map.to_list(params)
    from(DigioDoc, where: ^where) |> Repo.one()
  end

  def create_doc_details(params) do
    changeset = DigioDoc.changeset(%DigioDoc{}, params)
    Repo.insert!(changeset)
  end

  def update_doc_details(doc_id, params) do
    doc_details = get_doc_details_by(%{id: doc_id})
    changeset = DigioDoc.changeset(doc_details, params)
    Repo.update!(changeset)
  end
end
