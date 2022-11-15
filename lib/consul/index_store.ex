defmodule Consul.IndexStore do
  @moduledoc """
  This module keeps track of index values for consul blocking queries.
  """

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_index(url) do
    key = index_key(url)

    case :ets.lookup(__MODULE__, key) do
      [{_, value}] -> value
      _ -> nil
    end
  end

  def store_index(url, value) do
    key = index_key(url)

    with {pid, _} when is_pid(pid) <- key do
      GenServer.cast(__MODULE__, {:monitor, pid})
    end

    :ets.insert(__MODULE__, {key, value})
  end

  def reset_index(url) do
    key = index_key(url)
    :ets.delete(__MODULE__, key)
  end

  @impl GenServer
  def init(_) do
    __MODULE__ = :ets.new(__MODULE__, [:named_table, :public])
    {:ok, MapSet.new()}
  end

  @impl true
  def handle_cast({:monitor, pid}, monitored_pids) do
    monitored_pids =
      if MapSet.member?(monitored_pids, pid) do
        monitored_pids
      else
        Process.monitor(pid)
        MapSet.put(monitored_pids, pid)
      end

    {:noreply, monitored_pids}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, monitored_pids) do
    monitored_pids =
      if MapSet.member?(monitored_pids, pid) do
        :ets.match_delete(__MODULE__, {{pid, :_}, :_})
        MapSet.delete(monitored_pids, pid)
      else
        monitored_pids
      end

    {:noreply, monitored_pids}
  end

  defp index_key(url) do
    # make sure index values we store are local to the calling process
    {self(), url}
  end
end
