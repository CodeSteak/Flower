defmodule Flower.Native.BitArray.Stream do
  @moduledoc false
  defstruct bitarray_ref: nil, pos: 0

  alias Flower.Native.BitArray, as: BitArray

  defimpl Enumerable do
    # def reduce(_,       {:halt, acc}, _fun),   do: {:halted, acc}
    # def reduce(list,    {:suspend, acc}, fun), do: {:suspended, acc, &reduce(list, &1, fun)}
    # def reduce([],      {:cont, acc}, _fun),   do: {:done, acc}
    # def reduce([h | t], {:cont, acc}, fun),    do: reduce(t, fun.(h, acc), fun)

    def reduce(%{bitarray_ref: _ref, pos: _pos}, {:halt, acc}, _fun), do: {:halted, acc}

    def reduce(%{bitarray_ref: _ref, pos: _pos} = stream, {:suspend, acc}, fun),
      do: {:suspended, acc, &reduce(stream, &1, fun)}

    def reduce(%{bitarray_ref: _ref, pos: :eof}, {:cont, acc}, _fun), do: {:done, acc}

    def reduce(%{bitarray_ref: ref, pos: pos}, {:cont, acc}, fun) do
      {nextpos, data} = BitArray.to_bin_chunked(ref, pos)

      reduce(%{bitarray_ref: ref, pos: nextpos}, fun.(data, acc), fun)
    end

    def count(_stream) do
      {:error, __MODULE__}
    end

    def member?(_stream, _term) do
      {:error, __MODULE__}
    end

    def slice(_stream) do
      {:error, __MODULE__}
    end
  end

  defimpl Collectable do
    def into(%{bitarray_ref: _ref, pos: 0} = stream) do
      {stream, &collector_func/2}
    end

    defp collector_func(%{bitarray_ref: ref, pos: offset}, {:cont, elm}) when is_binary(elm) do
      next_offset = BitArray.or_chunk(ref, elm, offset)
      %{bitarray_ref: ref, pos: next_offset}
    end

    defp collector_func(%{bitarray_ref: ref, pos: _offset}, :done) do
      ref
    end

    defp collector_func(%{bitarray_ref: _ref, pos: _offset}, :halt) do
      :ok
    end
  end
end
