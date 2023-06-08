defmodule BnApis.Digio.Behaviour do
  alias BnApis.DigioDocs
  @callback upload_pdf_for_digio(String.t(), list(map()), map()) :: DigioDocs | nil
end
