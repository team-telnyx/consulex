defmodule Consul.IndexStore do
  @moduledoc """
  This module keeps track of index values for consul blocking queries.
  """

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_index(url) do
    case :ets.lookup(__MODULE__, url) do
      [{_, value}] -> value
      _ -> nil
    end
  end

  def store_index(url, value) do
    :ets.insert(__MODULE__, {url, value})
  end

  def reset_index(url) do
    :ets.delete(__MODULE__, url)
  end

  @impl GenServer
  def init(_) do
    __MODULE__ = :ets.new(__MODULE__, [:named_table, :public])
    {:ok, nil}
  end
end
