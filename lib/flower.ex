defmodule Flower.Bloom do
  use Bitwise
  alias Flower.Native.BitArray, as: BitArray

  @moduledoc """
  Flower.Bloom implements a Bloom Filter.

  For this Bloom Filter sha256 is used as hash function.
  """

  @ser_vsn 1

  @byte_sizes [
    :"8 Byte",
    :"16 Byte",
    :"32 Byte",
    :"64 Byte",
    :"128 Byte",
    :"256 Byte",
    :"512 Byte",
    :"1 KB",
    :"2 KB",
    :"4 KB",
    :"8 KB",
    :"16 KB",
    :"32 KB",
    :"64 KB",
    :"128 KB",
    :"256 KB",
    :"512 KB",
    :"1 MB",
    :"2 MB",
    :"4 MB",
    :"8 MB",
    :"16 MB",
    :"32 MB",
    :"64 MB",
    :"128 MB",
    :"256 MB",
    :"512 MB"
  ]

  @type bloomfilter ::
          {:bloom, bitarray :: reference(), bitaddrmask :: integer(), number_of_hashes :: 1..8}
  @type size_atom ::
          :"8 Byte"
          | :"16 Byte"
          | :"32 Byte"
          | :"64 Byte"
          | :"128 Byte"
          | :"256 Byte"
          | :"512 Byte"
          | :"1 KB"
          | :"2 KB"
          | :"4 KB"
          | :"8 KB"
          | :"16 KB"
          | :"32 KB"
          | :"64 KB"
          | :"128 KB"
          | :"256 KB"
          | :"512 KB"
          | :"1 MB"
          | :"2 MB"
          | :"4 MB"
          | :"8 MB"
          | :"16 MB"
          | :"32 MB"
          | :"64 MB"
          | :"128 MB"
          | :"256 MB"
          | :"512 MB"

  @doc """
  Create a new Bloom Filter with `size` :: `size_atom()` or 2^bitaddrlen bits.

  |bitaddrlen|    Size|Bitaddrlen|    Size|Bitaddrlen|    Size|
  |-------:|---------:|-------:|---------:|-------:|---------:|
  | __  __ |          | __13__ | 1 KB     | __23__ | 1 MB     |
  | __  __ |          | __14__ | 2 KB     | __24__ | 2 MB     |
  | __  __ |          | __15__ | 4 KB     | __25__ | 4 MB     |
  | __6 __ | 8 Byte   | __16__ | 8 KB     | __26__ | 8 MB     |
  | __7 __ | 16 Byte  | __17__ | 16 KB    | __27__ | 16 MB    |
  | __8 __ | 32 Byte  | __18__ | 32 KB    | __28__ | 32 MB    |
  | __9 __ | 64 Byte  | __19__ | 64 KB    | __29__ | 64 MB    |
  | __10__ | 128 Byte | __20__ | 128 KB   | __30__ | 128 MB   |
  | __11__ | 256 Byte | __21__ | 256 KB   | __31__ | 256 MB   |
  | __12__ | 512 Byte | __22__ | 512 KB   | __32__ | 512 MB   |
  """
  @spec new(bitaddrlen :: 6..32, expected_elements :: pos_integer()) :: bloomfilter()
  def new(bitaddrlen, expected_elements) when bitaddrlen in 6..32 do
    number_of_hashes = 1..8 |> Enum.min_by(&calc_fp_prob(expected_elements, 1 <<< bitaddrlen, &1))

    if number_of_hashes == 1 do
      IO.warn("Your Bloom filter is too small for the expected number of elements!")
    end

    {:bloom, BitArray.new(1 <<< bitaddrlen), (1 <<< bitaddrlen) - 1, number_of_hashes}
  end

  @spec new(bitaddrlen :: size_atom(), expected_elements :: pos_integer()) :: bloomfilter()
  def new(bytes, expected_elements) when bytes in @byte_sizes do
    bitaddrlen = 6 + Enum.find_index(@byte_sizes, fn x -> x == bytes end)
    new(bitaddrlen, expected_elements)
  end

  @doc """
  Create a new Bloom Filter with maximum byte size 'bytes'. The size gets
  rounded down to the next `size_atom()`.
  """
  @spec new_by_byte_size(bytes :: size_atom(), expected_elements :: pos_integer()) ::
          bloomfilter()
  def new_by_byte_size(bytes, expected_elements) when bytes in @byte_sizes do
    new(bytes, expected_elements)
  end

  @spec new_by_byte_size(bytes :: pos_integer(), expected_elements :: pos_integer()) ::
          bloomfilter()
  def new_by_byte_size(bytes, expected_elements) do
    bitaddrlen = trunc(:math.log2(bytes * 8))

    new(bitaddrlen, expected_elements)
  end

  defp calc_fp_prob(elem, size, number_of_hashes) do
    e = 2.71828182846
    fraction_of_0 = :math.pow(e, -number_of_hashes * elem / size)
    fraction_of_1 = 1 - fraction_of_0

    false_positives = :math.pow(fraction_of_1, number_of_hashes)
    false_positives
  end

  @doc """
  Calculates the false positive probability for a given bloom filter.
  Return value is between `0.0` and `1.0`.
  This Operation is slow for large Bloom Filters and should then be avoided.
  """
  @spec false_positive_probability(bloomfilter()) :: float()
  def false_positive_probability({:bloom, bitarray, _mask, number_of_hashes}) do
    fraction_of_1 = BitArray.count_ones(bitarray) / BitArray.bit_length(bitarray)
    false_positives = :math.pow(fraction_of_1, number_of_hashes)

    false_positives
  end

  @doc """
  Estimates how many unique elements have been added.
  This Operation is slow for large Bloom Filters and should then be avoided.
  """
  @spec estimate_count(bloomfilter()) :: non_neg_integer()
  def estimate_count({:bloom, bitarray, _mask, number_of_hashes}) do
    bits = BitArray.bit_length(bitarray)
    ones = BitArray.count_ones(bitarray)

    fraction_of_1 = ones / bits
    fraction_of_0 = 1 - fraction_of_1

    elmements = -1 * :math.log(fraction_of_0) * bits / number_of_hashes

    round(elmements)
  end

  @doc """
  Inserts an Erlang Term into the Bloom Filter.
  """
  @spec insert(bloomfilter(), any()) :: :ok
  def insert({:bloom, bitarray, mask, number_of_hashes}, bin) when is_binary(bin) do
    sha256 = :crypto.hash(:sha256, bin)

    hash_to_list(number_of_hashes, sha256)
    |> Enum.map(&Bitwise.&&&(&1, mask))
    |> write(bitarray)
  end

  def insert(bloom, term) do
    insert(bloom, :erlang.term_to_binary(term))
  end

  @doc """
  Checks if an element was inserted in the given Bloom Filter.

  Returns `false` if it can be guaranteed that the element was not
  inserted. Else `true`.

  You can get the probability of a false positive
  using `Flower.Bloom.false_positive_probability`.

  |Was actually inserted?|                  has?  |                    has_not?  |
  |:--------------------:|:----------------------:|:----------------------------:|
  | yes                  | yes                    |                       no     |
  | no                   | most of the times: no  |   most of the times: yes     |

  """
  @spec has?(bloomfilter(), any()) :: boolean()
  def has?({:bloom, bitarray, mask, number_of_hashes}, bin) when is_binary(bin) do
    sha256 = :crypto.hash(:sha256, bin)

    hash_to_list(number_of_hashes, sha256)
    |> Enum.map(&Bitwise.&&&(&1, mask))
    |> read(bitarray)
  end

  def has?(bloom, term) do
    has?(bloom, :erlang.term_to_binary(term))
  end

  @doc """
  Checks if an element is not in a given Bloom Filter.

  Returns `true` if it can be guaranteed that the element was not
  inserted. Else `false`.

  This is equal to `!Bloom.has?(filter, term)`
  """
  @spec has_not?(bloomfilter(), any()) :: boolean()
  def has_not?(bloom, term), do: !has?(bloom, term)

  @doc false
  @deprecated "This is unstable, can change soon"
  def serialize({:bloom, bitarray, _mask, number_of_hashes}) do
    blen = BitArray.bit_length(bitarray)
    bitaddrlen = :math.log2(blen) |> trunc()
    <<@ser_vsn, 42, bitaddrlen::8, number_of_hashes::8, BitArray.to_bin(bitarray)::binary>>
  end

  @doc false
  @deprecated "This is unstable, can change soon"
  def deserialize(<<@ser_vsn, 42, bitaddrlen::8, number_of_hashes::8, bitarray::binary>>) do
    {:bloom, BitArray.from_bin(bitarray), (1 <<< bitaddrlen) - 1, number_of_hashes}
  end

  defp write([p | tail], bitarray) do
    BitArray.put(bitarray, p, true)
    write(tail, bitarray)
  end

  defp write([], _) do
    :ok
  end

  defp read([p | tail], bitarray) do
    BitArray.get(bitarray, p) && read(tail, bitarray)
  end

  defp read([], _) do
    true
  end

  # TODO fix formater
  # defp hash_to_list(1, <<a::32,_b::32,_c::32,_d::32,_e::32,_f::32,_g::32,_h::32>>), do: [a]
  # defp hash_to_list(2, <<a::32,b::32,_c::32,_d::32,_e::32,_f::32,_g::32,_h::32>>), do: [a,b]
  # defp hash_to_list(3, <<a::32,b::32,c::32,_d::32,_e::32,_f::32,_g::32,_h::32>>), do: [a,b,c]
  # defp hash_to_list(4, <<a::32,b::32,c::32,d::32,_e::32,_f::32,_g::32,_h::32>>), do: [a,b,c,d]
  # defp hash_to_list(5, <<a::32,b::32,c::32,d::32,e::32,_f::32,_g::32,_h::32>>), do: [a,b,c,d,e]
  # defp hash_to_list(6, <<a::32,b::32,c::32,d::32,e::32,f::32,_g::32,_h::32>>), do: [a,b,c,d,e,f]
  # defp hash_to_list(7, <<a::32,b::32,c::32,d::32,e::32,f::32,g::32,_h::32>>), do: [a,b,c,d,e,f,g]
  # defp hash_to_list(8, <<a::32,b::32,c::32,d::32,e::32,f::32,g::32,h::32>>), do: [a,b,c,d,e,f,g,h]

  defp hash_to_list(1, <<a::32, _b::32, _c::32, _d::32, _e::32, _f::32, _g::32, _h::32>>), do: [a]

  defp hash_to_list(2, <<a::32, b::32, _c::32, _d::32, _e::32, _f::32, _g::32, _h::32>>),
    do: [a, b]

  defp hash_to_list(3, <<a::32, b::32, c::32, _d::32, _e::32, _f::32, _g::32, _h::32>>),
    do: [a, b, c]

  defp hash_to_list(4, <<a::32, b::32, c::32, d::32, _e::32, _f::32, _g::32, _h::32>>),
    do: [a, b, c, d]

  defp hash_to_list(5, <<a::32, b::32, c::32, d::32, e::32, _f::32, _g::32, _h::32>>),
    do: [a, b, c, d, e]

  defp hash_to_list(6, <<a::32, b::32, c::32, d::32, e::32, f::32, _g::32, _h::32>>),
    do: [a, b, c, d, e, f]

  defp hash_to_list(7, <<a::32, b::32, c::32, d::32, e::32, f::32, g::32, _h::32>>),
    do: [a, b, c, d, e, f, g]

  defp hash_to_list(8, <<a::32, b::32, c::32, d::32, e::32, f::32, g::32, h::32>>),
    do: [a, b, c, d, e, f, g, h]

  @doc false
  @deprecated "Use `has?` instead"
  def has_maybe?(a, b), do: has?(a, b)
end
