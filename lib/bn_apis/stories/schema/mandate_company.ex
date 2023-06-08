defmodule BnApis.Stories.Schema.MandateCompany do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mandate_companies" do
    field(:mandate_company_name, :string)
    timestamps()
  end

  @fields [
    :mandate_company_name
  ]

  @required_fields [
    :mandate_company_name
  ]
  @doc false
  def changeset(mandate_company, attrs \\ %{}) do
    mandate_company
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:mandate_company_name, name: :unique_mandate_company_name_index, message: "A Mandate Company with same name exists.")
  end
end
