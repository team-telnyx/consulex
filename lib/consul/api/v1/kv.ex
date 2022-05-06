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
              value = Base.decode64!(value)

              value =
                if Keyword.get(opts, :decode, true),
                  do: decode_value(value),
                  else: value

              Map.put(map, "Value", value)

            other ->
              other
          end)

        {:ok, %{env | body: result}}

      other ->
        other
    end
  end

  defp decode_value(value) do
    case JsonCodec.decode(value) do
      {:ok, map} ->
        map

      ## poison new releases return the position
      {:error, _, _pos} ->
        check_yaml(value)

      {:error, _} ->
        check_yaml(value)
    end
  end

  def check_yaml(value) do
    case YamlCodec.read_from_string(value) do
      {:ok, value} -> value
      {:error, _} -> raise RuntimeError, "expected JSON or YAML value"
    end
  end
end
