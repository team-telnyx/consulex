defmodule Consul.Api.V1.Kv do
  @moduledoc """
  Higher level abstraction on top of Consul's Key Value API.
  """

  alias Consul.{Connection, JsonCodec, Request, Response, YamlCodec}

  @doc """
  Get the value and metadata for a given key from the KV Store.
  """
  def get(connection, key, optional_params \\ [], opts \\ []) do
    optional_params_config = %{
      :dc => :query,
      :recurse => :query,
      :raw => :query,
      :keys => :query,
      :separator => :query,
      :ns => :query,
      :index => :query,
      :wait => :query
    }

    request =
      Request.new()
      |> Request.method(:get)
      |> Request.url("/v1/kv/{key}", %{
        "key" => key
      })
      |> Request.add_optional_params(optional_params_config, optional_params)

    connection
    |> Connection.execute(request)
    |> Response.decode(opts ++ [as: %{}])
    |> case do
      {:ok, %{body: results} = env} when is_list(results) ->
        result =
          results
          |> Enum.map(fn
            %{"Value" => value} = map when value != nil ->
              Map.put(map, "Value", decode_value(value))

            other ->
              other
          end)

        {:ok, %{env | body: result}}

      other ->
        other
    end
  end

  defp decode_value(value) do
    with value <- Base.decode64!(value),
         {:ok, map} <- JsonCodec.decode(value) do
      map
    else
      {:error, _} ->
        case YamlCodec.read_from_string(value) do
          {:ok, value} -> value
          {:error, _} -> raise RuntimeError, "expected JSON or YAML value"
        end
    end
  end
end
