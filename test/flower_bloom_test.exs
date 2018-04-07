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
    filter = Bloom.new(:"8 KB", 1000)

    for x <- 1..1_000 do
      Bloom.insert(filter, x)
    end

    # 1% should be okay
    assert Bloom.estimate_count(filter) - 1_000 < 10
  end

  test "stream into file and back" do
    File.rm("test/test.file3")

    filter = Bloom.new(:"128 KB", 1000)

    for x <- 1..1_000 do
      Bloom.insert(filter, "#{x}")
    end

    Bloom.stream(filter)
    |> Stream.into(File.stream!("test/test.file3", [], 1024))
    |> Stream.run()

    {:ok, filter2} = Bloom.from_stream(File.stream!("test/test.file3", [], 1024))

    assert Bloom.serialize(filter) == Bloom.serialize(filter2)
  end

  # This test takes too long then not run in production mode.
  if Mix.env() == :prod do
    test "stream into file and back 512MB" do
      File.rm("test/test.file2")

      filter = Bloom.new(:"512 MB", 1000)

      for x <- 1..1_000 do
        Bloom.insert(filter, "#{x}")
      end

      me = self()

      spawn_link(fn ->
        send(me, Bloom.stream(filter) |> hash_stream)
      end)

      Bloom.stream(filter)
      |> Stream.into(
        File.stream!(
          "test/test.file2",
          [:delayed_write, :read_ahead, :binary, :compressed],
          64 * 1024
        )
      )
      |> Stream.run()

      # Note: :compressed is only used because the Bloom filter is near empty
      {:ok, filter2} =
        Bloom.from_stream(
          File.stream!(
            "test/test.file2",
            [:delayed_write, :read_ahead, :binary, :compressed],
            64 * 1024
          )
        )

      spawn_link(fn ->
        send(me, Bloom.stream(filter2) |> hash_stream)
      end)

      hash_one =
        receive do
          a -> a
        after
          60_000 ->
            throw("failed")
        end

      hash_two =
        receive do
          a -> a
        after
          60_000 ->
            throw("failed")
        end

      assert hash_one == hash_two
    end

    defp hash_stream(stream) do
      stream
      |> Enum.reduce(:crypto.hash_init(:md5), fn bin, acc ->
        :crypto.hash_update(acc, bin)
      end)
      |> :crypto.hash_final()
    end
  end
end
