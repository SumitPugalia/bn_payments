defmodule BnApis.Seeder.TransactionDistrictSeed do

  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Transactions.District

  @districts [
  	"पुणे",
  	"सातारा",
  	"सांगली",
  	"कोल्हापूर",
  	"सोलापूर",
  	"ठाणे",
  	"रायगड",
  	"रत्नागिरी",
  	"सिंधुदुर्ग",
  	"नाशिक",
  	"जळगाव",
  	"धुळे",
  	"अहमदनगर",
  	"औरंगाबाद",
  	"जालना",
  	"बीड",
  	"लातूर",
  	"नांदेड",
  	"परभणी",
  	"उस्मानाबाद",
  	"अमरावती",
  	"यवतमाळ",
  	"अकोला",
  	"बुलढाणा",
  	"नागपूर",
  	"वर्धा",
  	"चंद्रपूर",
  	"भंडारा",
  	"गडचिरोली",
  	"मुंबई जिल्हा",
  	"मुंबई उपनगर जिल्हा",
  	"गोंदिया",
  	"वाशिम",
  	"हिंगोली",
  	"नंदुरबार",
  	"महाराष्ट्रातील इतर जिल्हे",
  	"महाराष्ट्र सोडून इतर जिल्हे",
  	"पालघर"
  ]

  def seed_data() do
    @districts |>
      Enum.each(fn(district_name) ->
        if District |> where(name: ^district_name) |> Repo.aggregate(:count, :id) == 0 do
          attrs = %{"name" => district_name}
          District.changeset(attrs) |> Repo.insert!
        end
      end)
  end
end