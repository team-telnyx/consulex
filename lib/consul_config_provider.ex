defmodule ConsulConfigProvider do
  @moduledoc """
  A Consul config provider.
  """

  @behaviour Config.Provider
  @dialyzer {:nowarn_function, load: 2}

  @impl true
  def init(opts), do: opts

  @impl true
  def load(config, _opts) do
    consul_configs =
      config
      |> get_config!()
      |> load_from_consul()

    __merge__(config, consul_configs)
  end

  defp load_from_consul({consul_http_addr, prefix, opts, transformer}) do
    connection = Consul.Connection.new(consul_http_addr, opts)

    {:ok, %{body: results}} = Consul.Api.V1.Kv.get(connection, prefix, keys: true)

    results
    |> Enum.map(fn path ->
      Task.async(fn ->
        {:ok, %{body: [%{"Key" => ^path, "Value" => value}]}} =
          Consul.Api.V1.Kv.get(connection, path)

        {String.replace_leading(path, prefix <> "/", ""), value}
      end)
    end)
    |> Enum.map(&Task.await/1)
    |> Enum.reduce([], fn {key, value}, acc ->
      key =
        key
        |> String.split("/")
        |> Enum.map(&String.to_atom/1)

      {key, value} =
        case transformer do
          nil -> {key, value}
          _ -> transformer.transform({key, value})
        end

      build(acc, key, value)
    end)
  end

  defp get_config!(config) do
    opts = Keyword.get(config, __MODULE__, [])

    consul_http_addr =
      case System.get_env("CONSUL_HTTP_ADDR", opts[:consul_http_addr]) do
        consul_http_addr when is_binary(consul_http_addr) ->
          case URI.parse(consul_http_addr) do
            %{scheme: scheme, host: host, port: port} = uri
            when scheme in ["http", "https"] and is_binary(host) and port != 0 ->
              to_string(%{uri | query: nil, path: nil})

            _ ->
              raise ArgumentError,
                    "expected :consul_http_addr option or CONSUL_HTTP_ADDR " <>
                      "env var to be a valid HTTP URL, got: #{inspect(consul_http_addr)}"
          end

        nil ->
          raise ArgumentError,
                "expected :consul_http_addr option or CONSUL_HTTP_ADDR " <>
                  "env var to be present"

        other ->
          raise ArgumentError,
                "expected :consul_http_addr option to be a string, got: " <> inspect(other)
      end

    prefix =
      case System.get_env("CONSUL_PREFIX", opts[:prefix]) do
        prefix when is_binary(prefix) ->
          parts = String.split(prefix, "/", trim: true)
          Enum.join(parts, "/")

        nil ->
          raise ArgumentError,
                "expected :consul_prefix option or CONSUL_PREFIX env var to be present"

        other ->
          raise ArgumentError,
                "expected :consul_prefix option to be a string, got: " <> inspect(other)
      end

    transformer = opts[:transformer]

    token_opts =
      case System.get_env("CONSUL_TOKEN") do
        nil -> []
        token -> [token: token]
      end

    opts = token_opts

    {consul_http_addr, prefix, opts, transformer}
  end

  defp build(keyword, [key], value), do: Keyword.put(keyword, key, value)

  defp build(keyword, [key | keys], value) do
    existing = Keyword.get(keyword, key, [])
    Keyword.put(keyword, key, build(existing, keys, value))
  end

  @doc false
  def __merge__(config1, config2) when is_list(config1) and is_list(config2),
    do: Keyword.merge(config1, config2, fn _, app1, app2 -> deep_merge(app1, app2) end)

  defp deep_merge(value1, value2) do
    if Keyword.keyword?(value1) and Keyword.keyword?(value2) do
      Keyword.merge(value1, value2, &deep_merge/3)
    else
      value2
    end
  end

  defp deep_merge(_key, value1, value2), do: deep_merge(value1, value2)

  @doc """
  Reload configurations from Consul.

  Notice that this function does not have the capability of removing existing
  configurations. If you remove keys from Consul, they will remain in the
  `Application` environment.
  """
  def reload(otp_app) do
    config =
      otp_app
      |> Application.get_all_env()
      |> load([])

    Application.put_all_env([{otp_app, config}])
  end
end
