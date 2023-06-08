defmodule MathThatShouldHaveBeenInStockElixirAlready do
  def int_pow10(num, 0), do: num
  def int_pow10(num, pow) when pow > 0, do: int_pow10(10 * num, pow - 1)
end

defmodule BnApis.Helpers.NumbersToWords do
  alias MathThatShouldHaveBeenInStockElixirAlready, as: Math

  def parse(0), do: "zero"

  def parse(number) when is_integer(number) do
    to_word(number)
    |> List.flatten()
    |> Enum.filter(& &1)
    |> Enum.join(" ")
  end

  def parse(unknown), do: raise(ArgumentError, message: "#{unknown} is not an integer")

  defp to_word(0), do: [nil]
  defp to_word(1), do: ["one"]
  defp to_word(2), do: ["two"]
  defp to_word(3), do: ["three"]
  defp to_word(4), do: ["four"]
  defp to_word(5), do: ["five"]
  defp to_word(6), do: ["six"]
  defp to_word(7), do: ["seven"]
  defp to_word(8), do: ["eight"]
  defp to_word(9), do: ["nine"]
  defp to_word(10), do: ["ten"]
  defp to_word(11), do: ["eleven"]
  defp to_word(12), do: ["twelve"]
  defp to_word(13), do: ["thirteen"]
  defp to_word(14), do: ["fourteen"]
  defp to_word(15), do: ["fifteen"]
  defp to_word(16), do: ["sixteen"]
  defp to_word(17), do: ["seventeen"]
  defp to_word(18), do: ["eighteen"]
  defp to_word(19), do: ["nineteen"]
  defp to_word(20), do: ["twenty"]
  defp to_word(30), do: ["thirty"]
  defp to_word(40), do: ["forty"]
  defp to_word(50), do: ["fifty"]
  defp to_word(60), do: ["sixty"]
  defp to_word(70), do: ["seventy"]
  defp to_word(80), do: ["eighty"]
  defp to_word(90), do: ["ninety"]
  defp to_word(n) when n < 0, do: ["negative", to_word(-n)]
  defp to_word(n) when n < 100, do: [to_word(div(n, 10) * 10), to_word(rem(n, 10))]
  defp to_word(n) when n < 1_000, do: [to_word(div(n, 100)), "hundred", to_word(rem(n, 100))]

  ~w[ thousand million billion trillion quadrillion quintillion sextillion septillion octillion nonillion decillion ]
  |> Enum.zip(2..13)
  |> Enum.each(fn {illion, factor} ->
    defp to_word(n) when n < unquote(Math.int_pow10(1, factor * 3)) do
      [
        to_word(div(n, unquote(Math.int_pow10(1, (factor - 1) * 3)))),
        unquote(illion),
        to_word(rem(n, unquote(Math.int_pow10(1, (factor - 1) * 3))))
      ]
    end
  end)

  defp to_word(_), do: raise(ArgumentError, message: "Dude. That number is too long. I don't know how to say it.")
end
