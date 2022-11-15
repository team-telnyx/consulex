defmodule Consul.IndexStoreTest do
  use ExUnit.Case
  alias Consul.IndexStore

  setup do
    {:ok, _} = start_supervised(IndexStore)
    :ok
  end

  test "get index for inexistent key" do
    key = key()
    assert IndexStore.get_index(key) |> is_nil()
  end

  test "store, get and reset index for key" do
    key = key()
    IndexStore.store_index(key, "1")

    assert IndexStore.get_index(key) == "1"

    IndexStore.reset_index(key)

    assert IndexStore.get_index(key) |> is_nil()
  end

  defp key do
    "http://consul/v1/kv/foo"
  end
end
