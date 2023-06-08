defmodule BnApis.Repo.Migrations.ModifyYoutubeAttachmentTypeName do
  use Ecto.Migration

  def up do
    execute("UPDATE stories_attachment_types SET name = 'YouTube URL' where id = 4;")
  end

  def down do
    execute("UPDATE stories_attachment_types SET name = 'You Tube URL' where id = 4;")
  end
end
