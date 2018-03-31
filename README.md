# Flower
[![Build Status](https://travis-ci.org/CodeSteak/Flower.svg?branch=master)](https://travis-ci.org/CodeSteak/Flower)

This is an implementation of __Bloom Filters for Elixir__. It uses __NIFs__ written __in Rust__ for better performance, since Bloom Filters rely highly on mutability.

#### What are Bloom Filter?
__TL;DR__: *Huge amount of data __➜__ small Bloom Filter __:__ Was X not in Huge amount of data?*

For more about this topic consider checking out:
* [Bloom Filters by Jason Davis](https://www.jasondavies.com/bloomfilter/)
* [Bloom Filters, Mining of Massive Datasets, Stanford University on Youtube](https://www.youtube.com/watch?v=qBTdukbzc78)

## Installation

The package can be installed by adding `flower` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:flower, "~> 0.1.1"},
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
# With an size atom
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
iex> Bloom.has_maybe?(filter, [1,2,{:atom, <<1,2,3,4>>}])
true
iex> Bloom.has_maybe?(filter, :atom)
false
# `has_maybe?` is allways the opposite of `has_not?`.
iex> Bloom.has_maybe?(filter, 42) != Bloom.has_not?(filter, 42)
true
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


# Select apropriate size.
# We will put about 100_000 elements in.
# 64 KB = 512 KBit
# 512 KBit / 100_000 ~= 5.25 Bits per element.
# Meeh. Lets see...
non_primes = Bloom.new(:"64 KB", 100_000)
# We can also write
non_primes = Bloom.new(19, 100_000)
# or (it will choose the next smaller size)
non_primes = Bloom.new_by_byte_size(64 * 1024, 100_000)

# Lets inspect the size.
byte_size(Bloom.serialize(non_primes))

# lets two non primes in:
Bloom.insert(non_primes, 42)
Bloom.insert(non_primes, "one hundred")
Bloom.insert(non_primes, [:ok, {Anything, 1.0e9}])

# Let's double check:
Bloom.has_maybe?(non_primes, 42)
Bloom.has_maybe?(non_primes, "one hundred")
Bloom.has_maybe?(non_primes, 7)
Bloom.has_maybe?(non_primes, [:ok, {Anything, 1.0e9}])
Bloom.has_maybe?(non_primes, 52)
# Works!


# Now we can get a estimate of
# the number of items we
# put in.
Bloom.estimate_count(non_primes)


# Apply Sieve of Eratosthenes
# This may take a few seconds.
# At least we can do it with
# constant memory.
for x <- 2..50_000 do
  # Skip multiples of previous numbers.
  # this is actually not safe to do
  # with a bloom filter since they are
  # aproximations. But let's don't care for now.
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

# Maybe a bit high, 64 KB for 100_000 Numbers
# is not that much.
Bloom.false_positive_probability(non_primes)

# Let's reestimate .
# There are 9_592 primes below 100_000, so this
# should yield about 100_000 - 9_592 = 90_408
Bloom.estimate_count(non_primes)
```
Side note: If you want to check primes, ~~google~~
search for *Miller–Rabin primality test*.

### Note
Please try avoiding calling the following functions often:
* `Bloom.false_positive_probability`
* `Bloom.estimate_count`
* `Bloom.serialize`
* `Bloom.deserialize`

They are expensive for larger sizes,
and therefore run on the Dirty CPU Scheduler.

`Bloom.serialize(Bloom.new(:"512 MB", 100))` can hang for __45 seconds!__
The data has to be copied since Elixir data types are immutable.
