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
  def call(%{url: url} = env, next, opts) do
    wait = Keyword.get(opts, :wait)

    env
    |> maybe_set_index(url)
    |> maybe_set_wait(wait)
    |> Tesla.run(next)
    |> store_index(url)
  end

  defp maybe_set_index(%{method: :get, query: query} = env, url) do
    index =
      case Keyword.fetch(query, :index) do
        {:ok, index} ->
          index

        _ ->
          IndexStore.get_index(url)
      end

    %{env | query: Keyword.put(query, :index, index)}
  end

  defp maybe_set_wait(%{query: query} = env, wait) do
    case Keyword.get(query, :index) do
      nil ->
        # don't set wait param on initial fetch
        env

      _ ->
        wait = Keyword.get(query, :wait, wait)
        %{env | query: Keyword.put(query, :wait, format_wait(wait))}
    end
  end

  defp store_index({:ok, env}, url) do
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
    current_index = IndexStore.get_index(url)

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

  defp format_wait(wait) when is_binary(wait), do: wait

  defp format_wait(duration) when is_number(duration) do
    duration = trunc(duration)

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

  defp format_wait(_), do: nil
end
