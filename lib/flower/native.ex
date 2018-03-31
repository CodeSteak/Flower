defmodule Flower.Native.BitArray do
  @moduledoc false

  use Rustler, otp_app: :flower, crate: :bitarray

  def new(_), do: :erlang.nif_error(:nif_not_loaded)
  def put(_, _, _), do: :erlang.nif_error(:nif_not_loaded)
  def get(_, _), do: :erlang.nif_error(:nif_not_loaded)
  def to_bin(_), do: :erlang.nif_error(:nif_not_loaded)
  def from_bin(_), do: :erlang.nif_error(:nif_not_loaded)
  def bit_length(_), do: :erlang.nif_error(:nif_not_loaded)
  def count_ones(_), do: :erlang.nif_error(:nif_not_loaded)
end
