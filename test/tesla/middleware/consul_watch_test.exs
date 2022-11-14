defmodule Tesla.Middleware.ConsulWatchTest do
  use ExUnit.Case
  import Tesla.Mock

  alias Tesla.Middleware.ConsulWatch

  @base_url "http://consul"
  @key "foo"

  setup do
    :ok = ConsulWatch.reset(%{url: "#{@base_url}/v1/kv/#{@key}"})
  end

  test "doesn't specify index on initial fetch" do
    mock(fn env -> {:ok, response(env, "100")} end)

    {:ok, %{query: query}} = Tesla.get(conn(), "/v1/kv/#{@key}")

    refute Keyword.has_key?(query, :index)
  end

  test "specifies index on subsequent requests" do
    mock(fn env -> {:ok, response(env, "100")} end)

    # initial fetch
    Tesla.get(conn(), "/v1/kv/#{@key}")

    # subsequent request
    {:ok, %{query: query}} = Tesla.get(conn(), "/v1/kv/#{@key}")

    assert query[:index] == 100
  end

  test "resets index when consul responds with index that is not greater than zero" do
    mock(fn %{query: query} = env ->
      case Keyword.get(query, :index) do
        nil -> {:ok, response(env, "100")}
        100 -> {:ok, response(env, "0")}
      end
    end)

    # initial fetch
    {:ok, %{query: query}} = Tesla.get(conn(), "/v1/kv/#{@key}")
    refute Keyword.has_key?(query, :index)

    # next request that returns index of 0
    {:ok, env} = Tesla.get(conn(), "/v1/kv/#{@key}")
    assert Tesla.get_header(env, "x-consul-index") == "0"

    # subsequent request
    {:ok, %{query: query}} = Tesla.get(conn(), "/v1/kv/#{@key}")
    refute Keyword.has_key?(query, :index)
  end

  test "resets index when consul responds with index that goes backwards" do
    mock(fn %{query: query} = env ->
      case Keyword.get(query, :index) do
        nil -> {:ok, response(env, "100")}
        100 -> {:ok, response(env, "50")}
      end
    end)

    # initial fetch
    {:ok, %{query: query}} = Tesla.get(conn(), "/v1/kv/#{@key}")
    refute Keyword.has_key?(query, :index)

    # next request that returns index of 50
    {:ok, env} = Tesla.get(conn(), "/v1/kv/#{@key}")
    assert Tesla.get_header(env, "x-consul-index") == "50"

    # subsequent request
    {:ok, %{query: query}} = Tesla.get(conn(), "/v1/kv/#{@key}")
    refute Keyword.has_key?(query, :index)
  end

  test "doesn't wait on initial fetch" do
    mock(fn env -> {:ok, response(env, "100")} end)

    {:ok, %{query: query}} =
      conn(wait: 123_456)
      |> Tesla.get("/v1/kv/#{@key}")

    refute Keyword.has_key?(query, :wait)
  end

  test "waits on subsequent requests" do
    mock(fn env -> {:ok, response(env, "100")} end)

    conn(wait: 123_456) |> Tesla.get("/v1/kv/#{@key}")

    {:ok, %{query: query}} =
      conn(wait: 123_456)
      |> Tesla.get("/v1/kv/#{@key}")

    assert query[:wait] == "2m3.456s"
  end

  defp conn(opts \\ []) do
    opts = Keyword.put_new(opts, :wait, 0)
    Consul.Connection.new(@base_url, [adapter: Tesla.Mock] ++ opts)
  end

  defp response(env, index) do
    body = %{
      "CreateIndex" => 1,
      "Flags" => 0,
      "Key" => @key,
      "LockIndex" => 0,
      "ModifyIndex" => index,
      "Value" => "bar"
    }

    headers = [{"x-consul-index", index}]

    %{env | status: 200, body: body, headers: headers}
  end
end
