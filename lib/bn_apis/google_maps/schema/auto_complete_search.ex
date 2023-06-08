defmodule BnApis.GoogleMaps.Schema.AutoCompleteSearch do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.GoogleMaps.Schema.AutoCompleteSearchResult

  schema "autocomplete_searches" do
    field :search_text, :string
    field :language, :string
    field :components, :string
    field :location_restriction, :string
    field :last_refreshed_at, :integer
    embeds_many :search_results, AutoCompleteSearchResult, on_replace: :delete
    timestamps()
  end

  @fields [:search_text, :language, :components, :location_restriction, :last_refreshed_at]
  @doc false
  def changeset(feedback, attrs) do
    feedback
    |> cast(attrs, @fields)
    |> cast_embed(:search_results)
    |> validate_required(@fields)
    |> unique_constraint(:name,
      name: :unique_autocomplete_search_result_with_filters_index,
      message: "Duplicate autocomplete records with filters found"
    )
  end
end
