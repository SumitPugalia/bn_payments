defmodule BnApis.Repo.Migrations.CreateBrokerCommissionTable do
  use Ecto.Migration

  def change do
    create table(:broker_commission) do
      add(:homeloan_by_bn_commission, :float)
      add(:homeloan_by_self_commission, :float)
      add(:commercial_loan_by_bn_commission, :float)
      add(:commercial_loan_by_self_commission, :float)
      add(:mortgage_loan_by_bn_commission, :float)
      add(:mortgage_loan_by_self_commission, :float)
      add(:business_loan, :float)
      add(:personal_loan, :float)
      add(:other_loan_type, :map)
      add(:broker_id, references(:brokers))

      timestamps()
    end
  end
end
