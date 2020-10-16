defmodule Consul.Response do
  @moduledoc """
  This module helps decode Tesla responses
  """

  alias Consul.JsonCodec

  @doc """
  Handle the response for a Tesla request

  ## Parameters

    * `response` (*type:* `{:ok, Tesla.Env.t} | {:error, reason}`) - The response object
    * `opts` (*type:* `keyword()`) - [optional] Optional parameters
      *   `:as` (*type:* `module()`) - If present, decode as struct or list.

  ## Returns

    * `{:ok, struct()}` on success
    * `{:error, Tesla.Env.t}` on failure
  """
  @spec decode({:ok, Tesla.Env.t()}, keyword()) :: {:ok, struct()} | {:error, Tesla.Env.t()}
  def decode(env, opts \\ [])

  def decode({:error, reason}, _), do: {:error, reason}

  def decode({:ok, %Tesla.Env{status: status} = env}, _)
      when status < 200 or status >= 300 do
    {:error, env}
  end

  def decode({:ok, %Tesla.Env{body: body} = env}, opts) do
    case Keyword.get(opts, :as) do
      nil ->
        {:ok, env}

      model ->
        case do_decode(body, as: model) do
          {:ok, body} -> {:ok, %{env | body: body}}
          other -> other
        end
    end
  end

  defp do_decode(nil, _opts), do: {:ok, nil}

  defp do_decode(body, opts), do: JsonCodec.decode(body, opts)
end
