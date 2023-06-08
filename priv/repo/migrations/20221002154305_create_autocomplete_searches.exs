defmodule BnApis.Repo.Migrations.CreateAutocompleteSearches do
  use Ecto.Migration

  def change do
    create table(:autocomplete_searches) do
      add(:search_text, :string, null: false)
      add(:language, :string)
      add(:components, :string)
      add(:location_restriction, :string)
      add(:last_refreshed_at, :integer, null: false)
      add(:search_results, {:array, :map}, default: [])
      timestamps()
    end

    create unique_index(
             :autocomplete_searches,
             [:search_text, :language, :components, :location_restriction],
             name: :unique_autocomplete_search_result_with_filters_index
           )
  end
end
