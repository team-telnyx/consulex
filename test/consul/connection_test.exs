defmodule Consul.ConnectionTest do
  use ExUnit.Case
  import Tesla.Mock

  @base_url "http://consul"
  @body String.duplicate("a", 1024)

  # Tesla < 1.18.3 ignores :max_body_size, so the cap is only enforced from there on.
  @bounded_tesla Version.match?(to_string(Application.spec(:tesla, :vsn)), ">= 1.18.3")

  setup do
    mock(fn env ->
      {:ok,
       %{env | status: 200, headers: [{"content-encoding", "gzip"}], body: :zlib.gzip(@body)}}
    end)

    :ok
  end

  test "decompresses a response under the default limit" do
    conn = Consul.Connection.new(@base_url, adapter: Tesla.Mock)

    assert {:ok, %{body: @body}} = Tesla.get(conn, "/v1/kv/foo")
  end

  test "decompresses a response under a custom limit" do
    conn = Consul.Connection.new(@base_url, adapter: Tesla.Mock, max_body_size: 1024)

    assert {:ok, %{body: @body}} = Tesla.get(conn, "/v1/kv/foo")
  end

  if @bounded_tesla do
    test "raises when a response inflates past max_body_size" do
      conn = Consul.Connection.new(@base_url, adapter: Tesla.Mock, max_body_size: 1023)

      error =
        assert_raise Tesla.Middleware.Compression.Error, fn ->
          Tesla.get(conn, "/v1/kv/foo")
        end

      assert error.reason == :max_body_size_exceeded
    end

    test "raises when a gzip bomb inflates past the default limit" do
      bomb = :zlib.gzip(:binary.copy(<<0>>, 17 * 1024 * 1024))

      mock(fn env ->
        {:ok, %{env | status: 200, headers: [{"content-encoding", "gzip"}], body: bomb}}
      end)

      conn = Consul.Connection.new(@base_url, adapter: Tesla.Mock)

      assert_raise Tesla.Middleware.Compression.Error, fn -> Tesla.get(conn, "/v1/kv/foo") end
    end
  end
end
