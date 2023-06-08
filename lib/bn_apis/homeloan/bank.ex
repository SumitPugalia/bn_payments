defmodule BnApis.Homeloan.Bank do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Homeloan.Bank
  alias BnApis.Homeloan.BankCodes
  alias BnApis.Helpers.S3Helper

  @seed_data %{
    1 => %{
      "name" => "HDFC",
      "order" => 1,
      "active" => true
    },
    2 => %{
      "name" => "ICICI",
      "order" => 2,
      "active" => true
    },
    3 => %{
      "name" => "Axis Bank",
      "order" => 3,
      "active" => true
    },
    4 => %{
      "name" => "Citi Bank",
      "order" => 4,
      "active" => true
    },
    5 => %{
      "name" => "Kotak Mahindra",
      "order" => 5,
      "active" => true
    },
    6 => %{
      "name" => "Yes Bank",
      "order" => 6,
      "active" => true
    },
    7 => %{
      "name" => "SBI",
      "order" => 7,
      "active" => true
    },
    8 => %{
      "name" => "PNB",
      "order" => 8,
      "active" => true
    },
    9 => %{
      "name" => "Tata Capital",
      "order" => 9,
      "active" => true
    },
    11 => %{
      "name" => "IDFC First",
      "order" => 11,
      "active" => true
    },
    12 => %{
      "name" => "LIC Housing",
      "order" => 12,
      "active" => true
    },
    13 => %{
      "name" => "HDFC LAP",
      "order" => 13,
      "active" => true
    },
    14 => %{
      "name" => "Axis ASHA",
      "order" => 14,
      "active" => true
    },
    15 => %{
      "name" => "Federal Bank",
      "order" => 15,
      "active" => true
    },
    16 => %{
      "name" => "IDBI Bank",
      "order" => 16,
      "active" => true
    },
    17 => %{
      "name" => "PNB HFL",
      "order" => 17,
      "active" => true
    },
    18 => %{
      "name" => "L&T",
      "order" => 18,
      "active" => true
    },
    19 => %{
      "name" => "Bank of Baroda",
      "order" => 19,
      "active" => true
    },
    20 => %{
      "name" => "IndusIND",
      "order" => 20,
      "active" => true
    },
    21 => %{
      "name" => "HDB",
      "order" => 21,
      "active" => true
    },
    22 => %{
      "name" => "IndiaBulls Home loans",
      "order" => 22,
      "active" => true
    },
    23 => %{
      "name" => "Hero Finance  HL",
      "order" => 23,
      "active" => true
    },
    24 => %{
      "name" => "AADHAR FINANCE",
      "order" => 24,
      "active" => true
    },
    25 => %{
      "name" => "DCB",
      "order" => 25,
      "active" => true
    },
    26 => %{
      "name" => "Bajaj Finance ( SENP)",
      "order" => 26,
      "active" => true
    },
    27 => %{
      "name" => "Bajaj Finance (SEP/Salaried)",
      "order" => 27,
      "active" => true
    },
    28 => %{
      "name" => "Godrej Finance Ltd",
      "order" => 28,
      "active" => true
    },
    29 => %{
      "name" => "Centrum Housing",
      "order" => 29,
      "active" => true
    },
    30 => %{
      "name" => "Bank of Maharashtra",
      "order" => 30,
      "active" => true
    },
    31 => %{
      "name" => "Bandhan Bank",
      "order" => 31,
      "active" => true
    },
    32 => %{
      "name" => "Aditya Birla Housing Finance",
      "order" => 32,
      "active" => true
    },
    33 => %{
      "name" => "Central Bank Of India",
      "order" => 33,
      "active" => true
    },
    34 => %{
      "name" => "IIFL",
      "order" => 34,
      "active" => true
    },
    35 => %{
      "name" => "Bank Of India",
      "order" => 35,
      "active" => true
    },
    36 => %{
      "name" => "Navi finance",
      "order" => 36,
      "active" => true
    },
    37 => %{
      "name" => "Navi finance",
      "order" => 37
    },
    38 => %{
      "name" => "INCRED Finance",
      "order" => 38,
      "active" => true
    },
    39 => %{
      "name" => "UCO Bank",
      "order" => 39,
      "active" => true
    },
    40 => %{
      "name" => "Aditya Birla Capital",
      "order" => 40,
      "active" => true
    },
    41 => %{
      "name" => "Vaastu Housing Finance",
      "order" => 41,
      "active" => true
    },
    42 => %{
      "name" => "Shreeram Finance",
      "order" => 42,
      "active" => true
    },
    43 => %{
      "name" => "Shubham Housing Development Finance Company Limited",
      "order" => 43,
      "active" => true
    },
    44 => %{
      "name" => "Finnable",
      "order" => 44,
      "active" => true
    },
    45 => %{
      "name" => "Godrej Finance Ltd",
      "order" => 45,
      "active" => true
    }
  }

  schema "homeloan_banks" do
    field(:name, :string)
    field(:logo_url, :string)
    field(:commission_on, Ecto.Enum, values: ~w(sanctioned_amount disbursement_amount)a)
    field(:is_editable, :boolean, default: false)
    field(:active, :boolean, default: false)
    field(:order, :integer)
    timestamps()
  end

  @required [:name, :is_editable, :active]
  @optional [:order, :logo_url, :commission_on]

  @hl %{
    "identifier" => "hl",
    "name" => "Home Loan",
    "panel_key" => "HL Code",
    "property_stage" => ["Ready to Move", "Under construction"],
    "loan_subtype_with_property_type" => [
      %{
        "loan_subtype_name" => "Fresh Home Loan-B2B",
        "property_type" => ["Residential"]
      },
      %{
        "loan_subtype_name" => "Fresh Home Loan-B2C",
        "property_type" => ["Residential"]
      },
      %{
        "loan_subtype_name" => "Affordable Home loan",
        "property_type" => ["Residential"]
      },
      %{
        "loan_subtype_name" => "Topup",
        "property_type" => ["Residential"]
      },
      %{
        "loan_subtype_name" => "Resale Purchase",
        "property_type" => ["Residential"]
      },
      %{
        "loan_subtype_name" => "Topup (Existing Loan)",
        "property_type" => ["Residential"]
      },
      %{
        "loan_subtype_name" => "Bank Transfer",
        "property_type" => ["Residential"]
      },
      %{
        "loan_subtype_name" => "Bank Transfer+Topup",
        "property_type" => ["Residential"]
      }
    ]
  }

  @commercial %{
    "identifier" => "commercial",
    "name" => "Commercial Loan (LAP/LRD)",
    "panel_key" => "LAP/LRD Code",
    "property_stage" => ["Ready to Move", "Under construction"],
    "loan_subtype_with_property_type" => [
      %{
        "loan_subtype_name" => "Fresh",
        "property_type" => ["Residential", "Commercial"]
      },
      %{
        "loan_subtype_name" => "Topup",
        "property_type" => ["Residential", "Commercial"]
      },
      %{
        "loan_subtype_name" => "Bank Transfer",
        "property_type" => ["Residential", "Commercial"]
      },
      %{
        "loan_subtype_name" => "Overdraft",
        "property_type" => []
      },
      %{
        "loan_subtype_name" => "Dropdown Overdraft",
        "property_type" => []
      },
      %{
        "loan_subtype_name" => "Bank Transfer+Topup",
        "property_type" => ["Residential", "Commercial"]
      }
    ]
  }

  @pl %{
    "identifier" => "pl",
    "name" => "Personal Loan",
    "panel_key" => "PL Code",
    "property_stage" => nil,
    "loan_subtype_with_property_type" => [
      %{
        "loan_subtype_name" => "Secured",
        "property_type" => []
      },
      %{
        "loan_subtype_name" => "Unsecured",
        "property_type" => []
      }
    ]
  }

  @bl %{
    "identifier" => "bl",
    "name" => "Business Loan",
    "panel_key" => "BL Code",
    "property_stage" => nil,
    "loan_subtype_with_property_type" => [
      %{
        "loan_subtype_name" => "Secured",
        "property_type" => []
      },
      %{
        "loan_subtype_name" => "Unsecured",
        "property_type" => []
      }
    ]
  }
  @wc %{
    "identifier" => "wc",
    "name" => "Working Capital",
    "panel_key" => "WC Code",
    "property_stage" => ["Ready to Move", "Under construction"],
    "loan_subtype_with_property_type" => [
      %{
        "loan_subtype_name" => "Secured",
        "property_type" => ["Residential", "Commercial"]
      },
      %{
        "loan_subtype_name" => "Unsecured",
        "property_type" => ["Residential", "Commercial"]
      }
    ]
  }
  @el %{
    "identifier" => "el",
    "name" => "Education Loan",
    "property_stage" => nil,
    "panel_key" => "EL Code",
    "empty_loan_subtype_property_type" => ["Residential"],
    "loan_subtype_with_property_type" => nil
  }
  @cl %{
    "identifier" => "cl",
    "name" => "Car Loan",
    "property_stage" => nil,
    "panel_key" => "CL Code",
    "loan_subtype_with_property_type" => [
      %{
        "loan_subtype_name" => "Secured",
        "property_type" => []
      }
    ]
  }
  @connector %{
    "identifier" => "connector",
    "name" => "Connector",
    "property_stage" => nil,
    "panel_key" => "Connector Code",
    "loan_subtype_with_property_type" => [
      %{
        "loan_subtype_name" => "Secured",
        "property_type" => []
      }
    ]
  }

  def loan_type_list() do
    [
      @hl,
      @commercial,
      @pl,
      @bl,
      @wc,
      @el,
      @cl,
      @connector
    ]
  end

  @doc false
  def changeset(bank, attrs) do
    bank
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:name, name: :uniq_homeloan_banks_name_active_idx)
  end

  def seed_data() do
    @seed_data
  end

  def get_bank_data(ids) do
    Repo.all(from(b in Bank, where: b.id in ^ids))
  end

  def get_bank_id_by_name(name) do
    Repo.one(from(b in Bank, where: b.name == ^name and b.active == true, select: b.id))
  end

  def get_bank_name_from_id(id) do
    Repo.one(from(b in Bank, where: b.id == ^id and b.active == true, select: b.name))
  end

  def get_commission_on_from_id(id) do
    Repo.one(from(b in Bank, where: b.id == ^id and b.active == true, select: b.commission_on))
  end

  def get_commission_on_from_bank_name(bank_name) do
    Repo.one(from(b in Bank, where: b.name == ^bank_name and b.active == true, select: b.commission_on))
  end

  def get_bank_logo_url_from_id(id) do
    Repo.one(from(b in Bank, where: b.id == ^id, select: b.logo_url))
  end

  def get_bank_full_logo_url_from_id(id) do
    logo_url = Repo.one(from(b in Bank, where: b.id == ^id, select: b.logo_url))
    if is_nil(logo_url), do: S3Helper.get_imgix_url("assets/default_bank_logo.png"), else: S3Helper.get_imgix_url(logo_url)
  end

  @spec get_all_bank_data :: any
  def get_all_bank_data() do
    Repo.all(
      from(b in Bank,
        order_by: [b.name],
        where: b.active == true
      )
    )
    |> Enum.map(fn b ->
      %{
        "id" => b.id,
        "name" => b.name,
        "is_editable" => b.is_editable,
        "logo_url" => get_bank_full_logo_url_from_id(b.id)
      }
    end)
  end

  def add_bank(
        params = %{
          "name" => name,
          "bn_codes" => bn_codes
        }
      ) do
    Repo.transaction(fn ->
      changeset(%Bank{}, %{
        name: name,
        is_editable: true,
        active: true,
        logo_url: params["logo_url"],
        commission_on: params["commission_on"]
      })
      |> Repo.insert()
      |> case do
        {:ok, changeset} ->
          BankCodes.add_bn_codes(bn_codes, changeset.id)

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  def add_bank(_), do: {:error, "Invalid Params"}

  def get_all_banks() do
    result =
      Repo.all(
        from(b in Bank,
          order_by: [b.name],
          where: b.active == true
        )
      )
      |> Enum.map(fn bank ->
        BankCodes.create_bank_code_response(bank)
      end)

    {:ok, result}
  end

  def update_bank_details(bank, params) do
    bn_codes = params["bn_codes"]
    if not is_nil(bn_codes), do: BankCodes.update_bank_codes(bn_codes, bank.id), else: nil

    Repo.update(changeset(bank, params))
  end

  def update_bank(params = %{"id" => bank_id}) do
    params = Map.take(params, ["name", "active", "bn_codes", "logo_url", "commission_on"])
    bank = Repo.get_by(Bank, id: bank_id)

    case bank do
      nil -> {:error, :not_found}
      bank -> update_bank_details(bank, params)
    end
  end
end
