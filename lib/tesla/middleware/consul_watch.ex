defmodule Tesla.Middleware.ConsulWatch do
  @moduledoc """
  Fills the request so it results in a Consul blocking query.

  ## Example usage

  ```
  defmodule Myclient do
    use Tesla
    plug Tesla.Middleware.ConsulWatch, wait: 60_000
  end
  ```
  """

  @behaviour Tesla.Middleware

  alias Consul.IndexStore

  @header_x_consul_index "x-consul-index"

  def reset(%{url: url}) do
    IndexStore.reset_index(url)
  end

  @impl Tesla.Middleware
  def call(env, next, opts) do
    env
    |> load_index(opts)
    |> Tesla.run(next)
    |> store_index()
  end

  defp load_index(%{method: :get, url: url} = env, opts) do
    case current_index(url) do
      nil ->
        env

      index ->
        query =
          case Keyword.get(opts, :wait) do
            nil -> []
            wait -> [wait: to_gotime(wait)]
          end

        query = [index: index] ++ query

        Map.update!(env, :query, &Keyword.merge(&1, query))
    end
  end

  defp load_index(env, _opts), do: env

  defp current_index(url) do
    IndexStore.get_index(url)
  end

  def to_gotime(duration) do
    ms =
      case rem(duration, 1_000) do
        0 ->
          ""

        ms ->
          <<"0", ms::binary>> = to_string(ms / 1_000)
          ms
      end

    duration = div(duration, 1_000)

    s =
      case rem(duration, 60) do
        0 -> if(ms == "", do: "", else: "0#{ms}s")
        s -> "#{s}#{ms}s"
      end

    duration = div(duration, 60)

    m =
      case rem(duration, 60) do
        0 -> s
        m -> "#{m}m#{s}"
      end

    case div(duration, 60) do
      0 -> m
      h -> "#{h}h#{m}"
    end
  end

  def store_index({:ok, %{url: url} = env}) do
    index =
      with [index | _] <- Tesla.get_headers(env, @header_x_consul_index),
           {index, _} <- Integer.parse(index) do
        index
      else
        _ -> nil
      end

    handle_new_index(url, index)

    {:ok, env}
  end

  def store_index({:error, reason}), do: {:error, reason}

  defp handle_new_index(url, nil) do
    IndexStore.reset_index(url)
  end

  defp handle_new_index(url, new_index) do
    current_index = current_index(url)

    cond do
      is_nil(current_index) ->
        IndexStore.store_index(url, new_index)

      new_index < current_index || new_index < 1 ->
        # reset index when it has moved backwards or is not greater than 0
        # see: https://www.consul.io/api-docs/features/blocking#implementation-details
        IndexStore.reset_index(url)

      true ->
        IndexStore.store_index(url, new_index)
    end
  end
end
