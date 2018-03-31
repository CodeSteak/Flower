defmodule BitArrayTest do
  use ExUnit.Case
  alias Flower.Native.BitArray, as: BitArray
  doctest Flower.Native.BitArray

  test "1000 Random Writes And Reads" do
    a = BitArray.new(1000)

    trues = 0..999 |> Enum.to_list() |> Enum.filter(fn _ -> :rand.uniform(2) == 1 end)

    for x <- 0..999 do
      BitArray.put(a, x, x in trues)
    end

    for x <- 0..999 do
      assert BitArray.get(a, x) == x in trues
    end
  end

  test "1000 Random Writes And Reads With Serialisation" do
    a = BitArray.new(1000)

    trues = 0..999 |> Enum.to_list() |> Enum.filter(fn _ -> :rand.uniform(2) == 1 end)

    for x <- 0..999 do
      BitArray.put(a, x, x in trues)
    end

    bin = BitArray.to_bin(a)
    bs = BitArray.from_bin(bin)

    for x <- 0..999 do
      assert BitArray.get(bs, x) == x in trues
    end
  end

  test "10_000 Random Writes True then False And Reads" do
    a = BitArray.new(10000)

    trues = 0..9999 |> Enum.to_list() |> Enum.filter(fn _ -> :rand.uniform(2) == 1 end)

    for x <- 0..9999 do
      BitArray.put(a, x, x in trues)
    end

    for x <- 0..9999 do
      BitArray.put(a, x, false)
    end

    for x <- 0..9999 do
      assert BitArray.get(a, x) == false
    end
  end

  test "Count Ones (len 10000)" do
    a = BitArray.new(10000)

    trues = 0..9999 |> Enum.to_list() |> Enum.filter(fn _ -> :rand.uniform(2) == 1 end)

    for x <- 0..9999 do
      BitArray.put(a, x, x in trues)
    end

    assert length(trues) == BitArray.count_ones(a)
  end

  test "Get Size" do
    a = BitArray.new(10000)
    assert abs(10000 - BitArray.bit_length(a)) <= 64
  end
end
