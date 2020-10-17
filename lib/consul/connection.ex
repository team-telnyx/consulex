defmodule Consul.Connection do
  @moduledoc """
  Handle Tesla connections for Consul.
  """

  @type t :: Tesla.Env.client()

  @default_scheme "http://"
  @consulex_version Mix.Project.config() |> Keyword.get(:version, "")

  @retry_defaults [
    delay: 50,
    max_retries: 5,
    max_delay: 4_000,
    should_retry: &Consul.Connection.match_errors/1
  ]

  @doc """
  Builds a base URL based on a given server spec.
  """
  def base_url(<<"http://", _::binary>> = server_spec),
    do: server_spec

  def base_url(<<"https://", _::binary>> = server_spec),
    do: server_spec

  def base_url(server_spec) do
    if Regex.match?(~r{^[^:/]+(:[0-9]+)?}, server_spec) do
      @default_scheme <> server_spec
    else
      raise ArgumentError,
            "expected :server_spec to be a valid URL or server spec, got: #{inspect(server_spec)}"
    end
  end

  @doc """
  Builds a Tesla client.
  """
  def new(base_url, opts \\ []) do
    middleware = [
      {Tesla.Middleware.BaseUrl, base_url},
      Tesla.Middleware.DecompressResponse,
      Tesla.Middleware.FollowRedirects
    ]

    opts = Keyword.update(opts, :retry, @retry_defaults, fn retry ->
      Keyword.merge(@retry_defaults, retry)
    end)

    middleware =
      Enum.reduce(opts, middleware, fn opt, middleware ->
        plug_middleware(opt, middleware)
      end)

    Tesla.client(middleware)
  end

  defp plug_middleware({:timeout, timeout}, middleware) do
    middleware ++ [{Tesla.Middleware.Timeout, timeout: timeout}]
  end

  defp plug_middleware({:token, token}, middleware) do
    middleware ++ [{Tesla.Middleware.Headers, [{"x-consul-token", token}]}]
  end

  defp plug_middleware({:wait, wait}, middleware) do
    middleware ++ [{Tesla.Middleware.ConsulWatch, wait: wait}]
  end

  defp plug_middleware({:retry, retry}, middleware) do
    middleware ++ [{Tesla.Middleware.Retry, retry}]
  end

  defp plug_middleware(_opt, middleware) do
    middleware
  end

  @doc """
  Converts a Consul.Request struct into a keyword list to send via
  Tesla.
  """
  @spec build_request(Consul.Request.t()) :: keyword()
  def build_request(request) do
    [url: request.url, method: request.method]
    |> build_query(request.query)
    |> build_headers(request.header)
    |> build_body(request.body)
  end

  defp build_query(output, []), do: output

  defp build_query(output, query_params) do
    Keyword.put(output, :query, query_params)
  end

  defp build_headers(output, header_params) do
    api_client =
      Enum.join(
        [
          "elixir/#{System.version()}",
          "consulex/#{@consulex_version}"
        ],
        " "
      )

    headers = [{"x-api-client", api_client} | header_params]
    Keyword.put(output, :headers, headers)
  end

  # If no body or file fields and the request is a POST, set an empty body
  defp build_body(output, []) do
    method = Keyword.fetch!(output, :method)
    set_default_body(output, method)
  end

  defp build_body(output, body: main_body) do
    Keyword.put(output, :body, main_body)
  end

  @required_body_methods [:post, :patch, :put, :delete]

  defp set_default_body(output, method) when method in @required_body_methods do
    Keyword.put(output, :body, "")
  end

  defp set_default_body(output, _) do
    output
  end

  @doc """
  Execute a request on this connection

  ## Returns

    * `{:ok, Tesla.Env.t}` - If the call was successful
    * `{:error, reason}` - If the call failed
  """
  @spec execute(Tesla.Client.t(), Consul.Request.t()) :: {:ok, Tesla.Env.t()}
  def execute(connection, request) do
    request
    |> build_request()
    |> (&Tesla.request(connection, &1)).()
  end

  def match_errors({:ok, %{status: status}}) when status >= 400, do: true
  def match_errors({:ok, _}), do: false
  def match_errors({:error, _}), do: true
end
