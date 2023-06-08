defmodule BnApis.Repo.Migrations.AddIndexOnPhoneNumberHl do
  use Ecto.Migration

  def up do
    execute(
      "CREATE INDEX pattern_index_homeloan_leads_phone_number ON homeloan_leads (lower(phone_number) varchar_pattern_ops)"
    )
  end

  def down do
    execute("DROP INDEX pattern_index_homeloan_leads_phone_number")
  end
end
