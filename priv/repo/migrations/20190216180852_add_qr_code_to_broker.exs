defmodule BnApis.Repo.Migrations.AddQrCodeToBroker do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      add :qr_code_url, :string
    end
  end
end
