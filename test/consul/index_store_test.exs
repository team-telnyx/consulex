defmodule Consul.IndexStoreTest do
  use ExUnit.Case
  alias Consul.IndexStore

  @url "http://consul/v1/kv/foo"

  setup do
    {:ok, _} = start_supervised(IndexStore)
    :ok
  end

  test "get index for inexistent url" do
    assert IndexStore.get_index(@url) |> is_nil()
  end

  test "store, get and reset index for url" do
    IndexStore.store_index(@url, "1")

    assert IndexStore.get_index(@url) == "1"

    IndexStore.reset_index(@url)

    assert IndexStore.get_index(@url) |> is_nil()
  end

  test "monitors storing process and cleans up when it goes down" do
    task =
      Task.async(fn ->
        IndexStore.store_index(@url, "1")
        assert IndexStore.get_index(@url) == "1"

        :timer.sleep(1000)
      end)

    :timer.sleep(100)
    assert [_] = :ets.tab2list(IndexStore)

    Task.shutdown(task)
    :timer.sleep(100)
    assert [] = :ets.tab2list(IndexStore)
  end
end
