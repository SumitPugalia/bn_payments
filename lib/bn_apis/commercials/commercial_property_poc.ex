defmodule BnApis.Commercials.CommercialPropertyPoc do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias BnApis.Commercials.CommercialPropertyPoc
  alias BnApis.Commercials.CommercialPropertyPocMapping
  alias BnApis.Helpers.FormHelper
  alias BnApis.Repo

  schema "commercial_property_pocs" do
    field :country_code, :string
    field :email, :string
    field :name, :string
    field :phone, :string
    field :type, :string
    field(:is_active, :boolean, default: true)

    has_many(:commercial_property_poc_mappings, CommercialPropertyPocMapping)

    timestamps()
  end

  @fields [:name, :email, :phone, :country_code, :type, :is_active]

  @doc false
  def changeset(commercial_property_poc, attrs) do
    commercial_property_poc
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> FormHelper.validate_email(:email)
    |> unique_constraint(:phone)
  end

  def get_poc_by_phone(phone) do
    CommercialPropertyPoc
    |> where([cpp], cpp.phone == ^phone)
    |> Repo.one()
  end

  def create_or_update_poc(phone_number, params) do
    case phone_number |> get_poc_by_phone() do
      nil ->
        create_poc(params)

      poc ->
        poc |> update_poc(params)
    end
  end

  def search_poc(search_text, is_active) do
    search_text = search_text |> String.trim() |> String.downcase()
    modified_search_text = "%" <> search_text <> "%"

    commercial_pocs =
      CommercialPropertyPoc
      |> where([c], ilike(c.name, ^modified_search_text) or ilike(c.phone, ^modified_search_text))
      |> where([c], c.is_active == ^is_active)
      |> order_by([c], fragment("lower(?) <-> ?", c.name, ^search_text))
      |> select(
        [c],
        %{
          country_code: c.country_code,
          email: c.email,
          name: c.name,
          phone: c.phone,
          type: c.type,
          is_active: c.is_active,
          poc_id: c.id
        }
      )
      |> Repo.all()

    response = %{"commercial_pocs" => commercial_pocs}
    {:ok, response}
  end

  # Private functions

  defp create_poc(attrs) do
    %CommercialPropertyPoc{}
    |> CommercialPropertyPoc.changeset(attrs)
    |> Repo.insert()
  end

  defp update_poc(poc, attrs) do
    poc
    |> CommercialPropertyPoc.changeset(attrs)
    |> Repo.update()
  end
end
