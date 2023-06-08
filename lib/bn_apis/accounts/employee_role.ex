defmodule BnApis.Accounts.EmployeeRole do
  use Ecto.Schema
  import Ecto.Changeset

  @admin %{id: 1, name: "Admin", admin_type: true}
  @member %{id: 2, name: "Member", admin_type: false}
  @super %{id: 3, name: "Super", admin_type: true}
  @transaction_data_cleaner %{id: 4, name: "Transaction Data Cleaner", admin_type: false}
  @quality_controller %{id: 5, name: "Quality Control Engineer", admin_type: false}
  @hl_super %{id: 6, name: "Homeloan Super", admin_type: true}
  @hl_agent %{id: 7, name: "Homeloan Agent", admin_type: false}
  @cab_admin %{id: 8, name: "Cab Admin", admin_type: true}
  @owner_supply_admin %{id: 9, name: "Owner Supply Admin", admin_type: true}
  @owner_supply_operations %{id: 10, name: "Owner Supply Operations", admin_type: false}
  @cab_operations_team %{id: 11, name: "Cab Operations Team", admin_type: false}
  @cab_operator %{id: 12, name: "Cab Operator", admin_type: false}
  @hl_executive %{id: 13, name: "Homeloan Executive", admin_type: false}
  @story_admin %{id: 14, name: "Story Admin", admin_type: true}
  @invoicing_admin %{id: 15, name: "Invoicing Admin", admin_type: true}
  @invoicing_operator %{id: 16, name: "Invoicing Operator", admin_type: false}
  @commercial_data_collector %{id: 17, name: "Commercial Data Collector", admin_type: false}
  @commercial_qc %{id: 18, name: "Commercial Qc", admin_type: false}
  @commercial_ops_admin %{id: 19, name: "Commercial Ops Admin", admin_type: true}
  @commercial_admin %{id: 20, name: "Commercial Admin", admin_type: true}
  @commercial_agent %{id: 21, name: "Commercial Agent", admin_type: false}
  @hr_admin %{id: 22, name: "HR Admin", admin_type: false}
  @broker_admin %{id: 23, name: "Broker Admin", admin_type: true}
  @owner_call_center_agent %{id: 24, name: "Owner Call Center Agent", admin_type: false}
  @owner_call_center_admin %{id: 25, name: "Owner Call Center Admin", admin_type: false}
  @bot_admin_user %{id: 26, name: "Bot Admin User", admin_type: true}
  @finance_admin %{id: 27, name: "Finance Admin", admin_type: false}
  @notification_admin %{id: 28, name: "Notification Admin", admin_type: true}
  @dsa_admin %{id: 29, name: "DSA Admin", admin_type: false}
  @dsa_super %{id: 30, name: "DSA Super", admin_type: true}
  @dsa_agent %{id: 31, name: "DSA Agent", admin_type: false}
  @investor %{id: 32, name: "Investor", admin_type: false}
  @assisted_admin %{id: 33, name: "Assisted Admin", admin_type: false}
  @assisted_manager %{id: 34, name: "Assisted Manager", admin_type: false}
  @bd_team %{id: 35, name: "BD Team", admin_type: false}
  @kyc_admin %{id: 36, name: "KYC Admin", admin_type: true}
  @dsa_finance %{id: 37, name: "DSA Finance", admin_type: true}

  def seed_data do
    [
      @admin,
      @member,
      @super,
      @transaction_data_cleaner,
      @quality_controller,
      @hl_super,
      @hl_agent,
      @cab_admin,
      @owner_supply_admin,
      @owner_supply_operations,
      @cab_operations_team,
      @cab_operator,
      @hl_executive,
      @story_admin,
      @invoicing_admin,
      @invoicing_operator,
      @commercial_data_collector,
      @commercial_qc,
      @commercial_ops_admin,
      @commercial_admin,
      @commercial_agent,
      @hr_admin,
      @broker_admin,
      @bot_admin_user,
      @owner_call_center_agent,
      @owner_call_center_admin,
      @finance_admin,
      @notification_admin,
      @dsa_admin,
      @dsa_super,
      @dsa_agent,
      @investor,
      @assisted_admin,
      @assisted_manager,
      @bd_team,
      @kyc_admin,
      @dsa_finance
    ]
  end

  @primary_key false
  schema "employees_roles" do
    field(:id, :integer, primary_key: true)
    field(:name, :string)

    timestamps()
  end

  @doc false
  def changeset(profile_type, params) do
    profile_type
    |> cast(params, [:id, :name])
    |> validate_required([:id, :name])
    |> unique_constraint(:name)
  end

  def changeset(params) do
    %__MODULE__{}
    |> changeset(params)
  end

  def admin do
    @admin
  end

  def member do
    @member
  end

  def super do
    @super
  end

  def transaction_data_cleaner do
    @transaction_data_cleaner
  end

  def quality_controller do
    @quality_controller
  end

  def hl_super do
    @hl_super
  end

  def hl_agent do
    @hl_agent
  end

  def cab_admin do
    @cab_admin
  end

  def owner_supply_admin do
    @owner_supply_admin
  end

  def owner_supply_operations do
    @owner_supply_operations
  end

  def cab_operations_team do
    @cab_operations_team
  end

  def cab_operator do
    @cab_operator
  end

  def hl_executive do
    @hl_executive
  end

  def story_admin do
    @story_admin
  end

  def invoicing_admin do
    @invoicing_admin
  end

  def invoicing_operator do
    @invoicing_operator
  end

  def commercial_data_collector do
    @commercial_data_collector
  end

  def commercial_qc do
    @commercial_qc
  end

  def commercial_ops_admin do
    @commercial_ops_admin
  end

  def commercial_admin do
    @commercial_admin
  end

  def commercial_agent do
    @commercial_agent
  end

  def hr_admin do
    @hr_admin
  end

  def broker_admin do
    @broker_admin
  end

  def owner_call_center_agent do
    @owner_call_center_agent
  end

  def owner_call_center_admin do
    @owner_call_center_admin
  end

  def bot_admin_user do
    @bot_admin_user
  end

  def finance_admin do
    @finance_admin
  end

  def notification_admin do
    @notification_admin
  end

  def dsa_admin do
    @dsa_admin
  end

  def dsa_super do
    @dsa_super
  end

  def dsa_agent do
    @dsa_agent
  end

  def investor do
    @investor
  end

  def assisted_admin do
    @assisted_admin
  end

  def assisted_manager do
    @assisted_manager
  end

  def bd_team do
    @bd_team
  end

  def kyc_admin do
    @kyc_admin
  end

  def dsa_finance do
    @dsa_finance
  end

  def get_by_id(id) do
    seed_data()
    |> Enum.filter(&(&1.id == id))
    |> List.first()
  end

  def get_by_name(name) do
    seed_data()
    |> Enum.filter(&(&1.name == name))
    |> List.first()
  end

  def is_dsa_employee(employee_role_id) do
    employee_role_id in [dsa_agent().id, dsa_admin().id, dsa_super().id]
  end
end
