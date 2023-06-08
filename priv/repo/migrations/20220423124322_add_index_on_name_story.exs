defmodule BnApis.Repo.Migrations.AddIndexOnNameStory do
  use Ecto.Migration

  def up do
    execute(
      "CREATE INDEX pattern_index_stories_name ON stories (lower(name) varchar_pattern_ops)"
    )
  end

  def down do
    execute("DROP INDEX pattern_index_stories_name")
  end
end
