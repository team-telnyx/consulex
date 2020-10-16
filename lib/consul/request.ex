defmodule Consul.Request do
  @moduledoc """
  This module is used to build an HTTP request
  """

  @path_template_regex ~r/{(\+?[^}]+)}/i

  defstruct method: :get, url: "", body: [], query: [], header: []

  @type param_location :: :body | :query | :header
  @type method :: :head | :get | :delete | :trace | :options | :post | :put | :patch
  @type t :: %__MODULE__{
          method: method(),
          url: String.t(),
          body: keyword(),
          query: keyword(),
          header: keyword()
        }

  @spec new() :: Consul.Request.t()
  def new do
    %__MODULE__{}
  end

  @spec method(Consul.Request.t()) :: {:ok, atom()} | :error
  def method(request), do: Map.fetch(request, :method)

  @doc """
  Specify the request method when building a request

  ## Parameters

  *   `request` (*type:* `Consul.Request.t`) - Collected request options
  *   `m` (*type:* `String`) - Request method

  ## Returns

  *   `Consul.Request.t`
  """
  @spec method(Consul.Request.t(), atom()) :: Consul.Request.t()
  def method(request, m) do
    %{request | method: m}
  end

  @spec url(Consul.Request.t()) :: {:ok, String.t()} | :error
  def url(request), do: Map.fetch(request, :url)

  @doc """
  Specify the request URL when building a request

  ## Parameters

  *   `request` (*type:* `Consul.Request.t`) - Collected request options
  *   `u` (*type:* `String`) - Request URL

  ## Returns

  *   `Consul.Request.t`
  """
  @spec url(Consul.Request.t(), String.t(), map()) :: Consul.Request.t()
  def url(request, u, replacements) do
    url(request, replace_path_template_vars(u, replacements))
  end

  def url(request, u) do
    Map.put(request, :url, u)
  end

  defp replace_path_template_vars(u, replacements) do
    Regex.replace(@path_template_regex, u, fn _, var -> replacement_value(var, replacements) end)
  end

  defp replacement_value("+" <> name, replacements) do
    URI.decode(replacement_value(name, replacements))
  end

  defp replacement_value(name, replacements) do
    replacements
    |> Map.get(name, "")
    |> to_string
  end

  @doc """
  Add optional parameters to the request

  ## Parameters

  * `request` (*type:* `Consul.Request.t`) - Collected request options
  * `definitions` (*type:* `Map`) - Map of parameter name to parameter location
  * `options` (*type:* `keyword()`) - The provided optional parameters

  ## Returns

  * `Consul.Request.t`
  """
  @spec add_optional_params(
          Consul.Request.t(),
          %{optional(atom()) => param_location()},
          keyword()
        ) :: Consul.Request.t()
  def add_optional_params(request, _, []), do: request

  def add_optional_params(request, definitions, [{key, value} | tail]) do
    case definitions do
      %{^key => location} ->
        request
        |> add_param(location, key, value)
        |> add_optional_params(definitions, tail)

      _ ->
        add_optional_params(request, definitions, tail)
    end
  end

  @doc """
  Add optional parameters to the request

  ## Parameters

  * `request` (*type:* `Consul.Request.t`) - Collected request options
  * `location` (*type:* `atom()`) - Where to put the parameter
  * `key` (*type:* `atom()`) - The name of the parameter
  * `value` (*type:* `any()`) - The value of the parameter

  ## Returns

  *   `Consul.Request.t`
  """
  @spec add_param(Consul.Request.t(), param_location(), atom(), any()) ::
          Consul.Request.t()
  def add_param(request, :query, key, values) when is_list(values) do
    Enum.reduce(values, request, fn value, req ->
      add_param(req, :query, key, value)
    end)
  end

  def add_param(request, location, key, value) do
    Map.update!(request, location, &(&1 ++ [{key, value}]))
  end
end
