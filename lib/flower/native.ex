defmodule Flower.Native.BitArray do
  @moduledoc false

  use Rustler, otp_app: :flower, crate: :bitarray

  def new(_), do: :erlang.nif_error(:nif_not_loaded)
  def put(_, _, _), do: :erlang.nif_error(:nif_not_loaded)
  def get(_, _), do: :erlang.nif_error(:nif_not_loaded)
  def to_bin_chuncked(_, _), do: :erlang.nif_error(:nif_not_loaded)
  def or_chunk(_, _, _), do: :erlang.nif_error(:nif_not_loaded)
  def bit_length(_), do: :erlang.nif_error(:nif_not_loaded)
  def count_ones(_), do: :erlang.nif_error(:nif_not_loaded)

  def to_bin(ref) do
    to_bin(ref, {0, <<>>})
  end

  def to_bin(_ref, {:eof, data}) do
    data
  end

  def to_bin(ref, {next_chunck, data}) do
    data <>
      to_bin(
        ref,
        to_bin_chuncked(ref, next_chunck)
      )
  end

  def from_bin(bin) do
    ref =
      bin
      |> bit_size()
      |> new()

    ref
    |> or_chunk(bin, 0)

    ref
  end
end
