defmodule BnApis.Repo.Migrations.AddChatAuthTokenToCredential do
  use Ecto.Migration

  def change do
    alter table(:credentials) do
      add :chat_auth_token, :string
    end
  end
end
