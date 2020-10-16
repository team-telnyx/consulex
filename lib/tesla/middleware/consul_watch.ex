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

  use GenServer

  @default_wait 60_000
  @header_x_consul_index "x-consul-index"
  @index_table Module.concat(__MODULE__, "Indexes")

  def reset(%{url: url}) do
    GenServer.call(__MODULE__, {:reset, url})
  end

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    @index_table = :ets.new(@index_table, [:named_table, :public])

    {:ok, []}
  end

  @impl GenServer
  def handle_call({:reset, url}, _from, state) do
    :ets.delete(@index_table, url)

    {:reply, :ok, state}
  end

  @impl Tesla.Middleware
  def call(env, next, opts) do
    env
    |> load_index(opts)
    |> Tesla.run(next)
    |> store_index()
  end

  defp load_index(%{method: :get, url: url} = env, opts) do
    case :ets.lookup(@index_table, url) do
      [] ->
        env

      [{_, index}] ->
        wait =
          Keyword.get(opts, :wait, @default_wait)
          |> to_gotime()

        env
        |> Map.update!(:query, &(&1 ++ [wait: wait, index: index]))
    end
  end

  defp load_index(env, _opts), do: env

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
    case Tesla.get_header(env, @header_x_consul_index) do
      nil ->
        :ets.delete(@index_table, url)

      index ->
        :ets.insert(@index_table, {url, index})
    end

    {:ok, env}
  end

  def store_index({:error, reason}), do: {:error, reason}
end
