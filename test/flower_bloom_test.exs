defmodule FlowerBloomTest do
  use ExUnit.Case
  doctest Flower.Bloom

  alias Flower.Bloom, as: Bloom

  defp random_elements do
    n = :rand.uniform(1000) + 100
    0..n |> Enum.map(fn x -> 1000 * x + :rand.uniform(1000) end)
  end

  test "Test constructors" do
    non_primes_a = Bloom.new(:"64 KB", 100_000)
    non_primes_b = Bloom.new(19, 100_000)
    non_primes_c = Bloom.new_by_byte_size(64 * 1024, 100_000)

    assert Bloom.serialize(non_primes_a) == Bloom.serialize(non_primes_b)
    assert Bloom.serialize(non_primes_b) == Bloom.serialize(non_primes_c)
  end

  test "Reserialize" do
    filter = Bloom.new(:"16 KB", 10_000)

    for x <- random_elements() do
      Bloom.insert(filter, "#{x}")
      Bloom.insert(filter, x)
    end

    Bloom.insert(filter, random_elements())

    bin = Bloom.serialize(filter)
    assert bin == bin |> Bloom.deserialize() |> Bloom.serialize()
  end

  test "insert elements" do
    filter = Bloom.new(:"64 KB", 1000)

    Bloom.insert(filter, 42)
    Bloom.insert(filter, "one hundred")
    Bloom.insert(filter, [:ok, {Anything, 1.0e9}])

    assert Bloom.has_maybe?(filter, 42)
    assert Bloom.has_maybe?(filter, "one hundred")
    assert Bloom.has_not?(filter, 7)
    assert Bloom.has_maybe?(filter, [:ok, {Anything, 1.0e9}])
    assert Bloom.has_not?(filter, 52)
  end

  test "false positive probability" do
    filter = Bloom.new(:"64 KB", 10_000)

    for x <- 1..10_000 do
      Bloom.insert(filter, x)
    end

    real_false_positives =
      (for x <- 1..20_000 do
         if Bloom.has_maybe?(filter, x) do
           1
         else
           0
         end
       end
       |> Enum.sum()) - 10_000

    calc_false_positives = 10_000 * Bloom.false_positive_probability(filter)

    # 0.1% should be okay
    assert abs(real_false_positives - calc_false_positives) < 10
  end

  test "estimate count" do
    filter = Bloom.new(:"8 KB", 10_000)

    for x <- 1..1_000 do
      Bloom.insert(filter, x)
    end

    # 1% should be okay
    assert Bloom.estimate_count(filter) - 1_000 < 10
  end
end
