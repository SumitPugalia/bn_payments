defmodule BnApis.Homeloan.LeadType do
  @salaried %{id: 1, name: "Salaried"}
  @self_employed %{id: 2, name: "Self Employed"}
  @nri %{id: 3, name: "NRI"}
  @not_employed %{id: 4, name: "Not Employed"}

  def employment_type_list() do
    [
      @salaried,
      @self_employed,
      @nri,
      @not_employed
    ]
  end
end
