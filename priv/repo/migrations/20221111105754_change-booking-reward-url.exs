defmodule BnApis.Repo.Migrations.ChangeBookingRewardURL do
  use Ecto.Migration

  def change do
    alter table(:booking_rewards_leads) do
      modify :developer_response_pdf, :text, from: :string
    end

    alter table(:invoices) do
      modify :invoice_pdf_url, :text, from: :string
      modify :proof_urls, {:array, :text}, from: {:array, :string}
    end
  end
end
