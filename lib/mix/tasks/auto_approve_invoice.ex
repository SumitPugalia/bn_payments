defmodule Mix.Tasks.AutoApproveInvoice do
  use Mix.Task
  import Ecto.Query
  alias BnApis.Stories.Schema.Invoice
  alias BnApis.BookingRewards.Schema.BookingRewardsLead
  alias BnApis.BookingRewards.Status
  alias BnApis.Schemas.LegalEntityPoc
  alias BnApis.Stories.Schema.PocApprovals
  alias BnApis.Helpers.Utils
  alias BnApis.Repo
  alias BnApis.Helpers.AuditedRepo

  @approved_by_bn_status_id Status.get_status_id!("approved_by_bn")
  @approved_by_crm_status_id Status.get_status_id!("approved_by_crm")
  @valid_invoices [Invoice.type_brokerage(), Invoice.type_reward()]

  def run(_) do
    Mix.Task.run("app.start", [])
    cron_user_map = Utils.get_employee_user_map(%{"phone_number" => "cron", "country_code" => "+91"})

    Repo.transaction(
      fn ->
        Invoice
        |> where([i], i.status == "approved" and i.type in ^@valid_invoices)
        |> Repo.stream()
        |> Stream.each(fn inv ->
          Invoice
          |> where([i], i.id == ^inv.id)
          |> update([i], set: [status: "approved_by_crm"])
          |> Repo.update_all([])

          BnApis.Stories.Invoice.auto_approve_by_bn_bots(inv, cron_user_map)
        end)
        |> Stream.run()

        IO.inspect("Invoice complete")

        BookingRewardsLead
        |> where([i], i.status_id == ^@approved_by_bn_status_id)
        |> Repo.stream()
        |> Stream.each(fn lead ->
          from(l in BookingRewardsLead, where: l.id == ^lead.id, update: [set: [status_id: ^@approved_by_crm_status_id]])
          |> Repo.update_all([])

          auto_approve_by_bn_bots(lead, cron_user_map)
        end)
        |> Stream.run()
      end,
      timeout: :infinity
    )

    IO.inspect("Booking complete")
  end

  def auto_approve_by_bn_bots(lead, user_map) do
    LegalEntityPoc.auto_approve_bots()
    |> Enum.reduce(true, fn poc, acc ->
      PocApprovals.new(%{
        role_type: poc.poc_type,
        action: "approved",
        legal_entity_poc_id: poc.id,
        booking_rewards_lead_id: lead.id,
        approved_at: DateTime.to_unix(DateTime.utc_now())
      })
      |> AuditedRepo.insert(user_map)
      |> case do
        {:ok, _poc_approval} -> true or acc
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end
end
