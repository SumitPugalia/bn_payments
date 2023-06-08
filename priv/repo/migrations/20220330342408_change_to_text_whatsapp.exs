defmodule BnApis.Repo.Migrations.ChangeToTextWhatsapp do
  use Ecto.Migration

  def change do
    alter table(:whatsapp_requests) do
      modify :template_vars, {:array, :text}
    end
  end
end
