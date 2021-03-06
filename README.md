# Flower
[![Build Status](https://travis-ci.org/CodeSteak/Flower.svg?branch=master)](https://travis-ci.org/CodeSteak/Flower)
[![Hex.pm](https://img.shields.io/hexpm/v/flower.svg)](https://hex.pm/packages/flower)


This is an implementation of __Bloom Filters for Elixir__. It uses __NIFs__ written __in Rust__ for better performance, since Bloom Filters rely highly on mutability.

#### What are Bloom Filter?
__TL;DR__: *Huge amount of data __➜__ small Bloom Filter __:__ Was X not in Huge amount of data?*

For more about this topic consider, checking out:
* [Bloom Filters by Jason Davis](https://www.jasondavies.com/bloomfilter/)
* [Bloom Filters, Mining of Massive Datasets, Stanford University on Youtube](https://www.youtube.com/watch?v=qBTdukbzc78)

## Installation

The package can be installed by adding `flower` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:flower, "~> 0.1.4"},
  ]
end
```

Also, you need to have __Rust__ installed for development, since this uses NIFs.

Docs can be found at [https://hexdocs.pm/flower](https://hexdocs.pm/flower).

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc).

## Usage
There is also a small walk through in the [Example Section](#example)
```elixir
alias Flower.Bloom, as: Bloom
```
##### Create new Bloom Filter
```elixir
expected_number_of_unique_elements = 1000
# With a size atom
iex> filter = Bloom.new(:"8 KB", expected_number_of_unique_elements)
...
# Or by a maximum byte size:
iex> filter = Bloom.new_by_byte_size(8 * 1024, expected_number_of_unique_elements)
...
# Or by a bit address length:
iex> filter = Bloom.new(16, expected_number_of_unique_elements)
...
```
| Bit Address Length|Size Atom| Bit Address Length|Size Atom| Bit Address Length|Size Atom|
|-------:|---------:|-------:|---------:|-------:|---------:|
|        |          | __13__ | 1 KB     | __23__ | 1 MB     |
|        |          | __14__ | 2 KB     | __24__ | 2 MB     |
|        |          | __15__ | 4 KB     | __25__ | 4 MB     |
|  __6__ | 8 Byte   | __16__ | 8 KB     | __26__ | 8 MB     |
|  __7__ | 16 Byte  | __17__ | 16 KB    | __27__ | 16 MB    |
|  __8__ | 32 Byte  | __18__ | 32 KB    | __28__ | 32 MB    |
|  __9__ | 64 Byte  | __19__ | 64 KB    | __29__ | 64 MB    |
| __10__ | 128 Byte | __20__ | 128 KB   | __30__ | 128 MB   |
| __11__ | 256 Byte | __21__ | 256 KB   | __31__ | 256 MB   |
| __12__ | 512 Byte | __22__ | 512 KB   | __32__ | 512 MB   |

##### Insert Elements
```elixir
iex> Bloom.insert(filter, 42)
:ok
iex> Bloom.insert(filter, [1,2,{:atom, <<1,2,3,4>>}])
:ok
iex> Bloom.insert(filter, "Hello!")
:ok
```

##### Check for Elements
```elixir
iex> Bloom.has_not?(filter, "Hello!")
false
iex> Bloom.has?(filter, [1,2,{:atom, <<1,2,3,4>>}])
true
iex> Bloom.has?(filter, :atom)
false
# `has?` is always the opposite of `has_not?`.
iex> Bloom.has?(filter, 42) != Bloom.has_not?(filter, 42)
true
```

|Was actually inserted?|                  has?  |                    has_not?  |
|:--------------------:|:----------------------:|:----------------------------:|
| yes                  | yes                    |                       no     |
| no                   | most of the times: no  |   most of the times: yes     |


##### Write To Disk

```elixir
filename = "prime_filter.bloom"
file = File.stream!(filename, [:delayed_write, :binary], 8096)

(Bloom.stream(filter) |> Stream.into(file) |> Stream.run)
```

##### Read From Disk

```elixir
filename = "prime_filter.bloom"
file = File.stream!(filename, [:read_ahead, :binary], 8096)

{:ok, new_filter} = Bloom.from_stream(file)
```

##### Funky Stuff
```elixir
iex> Bloom.estimate_count(filter)
3
iex> Bloom.false_positive_probability(filter)
3.2348227494719115e-28
# This number is only that small, because we have just 3 elements in 8 KBs.
```
## <a name="example"></a>Example
### Prime Numbers
Checking if a number is not a prime and below `100_000`.
```elixir
# helper module
defmodule Step do
    def throught(from, to, step, func) when from < to do
        func.(from)
        throught(from+step, to, step, func)
    end
    def throught(_,_,_,_), do: :ok
end && :ok

# alias so we need to write less
alias Flower.Bloom, as: Bloom


# Select appropriate size.
# We will put about 100_000 elements in.
# 64 KB = 512 KBit
# 512 KBit / 100_000 ~= 5.25 Bits per element.
# Meeh. Let's see...
non_primes = Bloom.new(:"64 KB", 100_000)
# We can also write
non_primes = Bloom.new(19, 100_000)
# or (it will choose the next smaller size)
non_primes = Bloom.new_by_byte_size(64 * 1024, 100_000)

# Let's put some non primes in:
Bloom.insert(non_primes, 42)
Bloom.insert(non_primes, "one hundred")
Bloom.insert(non_primes, [:ok, {Anything, 1.0e9}])

# Let's double check:
Bloom.has?(non_primes, 42)
Bloom.has?(non_primes, "one hundred")
Bloom.has?(non_primes, 7)
Bloom.has?(non_primes, [:ok, {Anything, 1.0e9}])
Bloom.has?(non_primes, 52)
# Works!


# Now we can get a estimate of
# the number of items we
# put in.
Bloom.estimate_count(non_primes)


# Apply Sieve of Eratosthenes.
# This may take a few seconds.
# At least we can do it with
# constant memory.
for x <- 2..50_000 do
  # Skip multiples of previous numbers.
  # This is actually not safe to do
  # with a bloom filter since they are
  # approximations. But let's don't care for now.
  if(Bloom.has_not?(non_primes, x)) do
    Step.throught(x*2, 100_000, x, fn non_prime ->
        # Much of the time is used to calculate
        # hashes.
        Bloom.insert(non_primes, non_prime)
    end)
 end
end && :ok

non_primes |> Bloom.has_not?(12) # not a prime
non_primes |> Bloom.has_not?(11) # prime
non_primes |> Bloom.has_not?(6719) # no prime
non_primes |> Bloom.has_not?(4245) # prime
non_primes |> Bloom.has_not?(9973) # no prime
non_primes |> Bloom.has_not?(3549) # prime
non_primes |> Bloom.has_not?(89591) # prime
non_primes |> Bloom.has_not?(84949) # no prime

# Let's write it to disk:
filename = "prime_filter.bloom"
file = File.stream!(filename, [:delayed_write, :read_ahead, :binary], 8096)
(Bloom.stream(non_primes)
|> Stream.into(file)
|> Stream.run)
# Let's inspect the size of the filter:
File.lstat!(filename).size

# We can also read from disk:
{:ok, new_non_primes} = Bloom.from_stream(file)
new_non_primes |> Bloom.has_not?(12) # not a prime
new_non_primes |> Bloom.has_not?(11) # prime
# Works!

# Maybe a bit high, 64 KB for 100_000 Numbers
# is not that much.
Bloom.false_positive_probability(non_primes)

# Let's reestimate .
# There are 9_592 primes below 100_000, so this
# should yield about 100_000 - 9_592 = 90_408.
Bloom.estimate_count(non_primes)
```
Side note: If you want to check primes, ~~google~~
search for *Miller–Rabin primality test*.
