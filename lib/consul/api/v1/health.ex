defmodule Consul.Api.V1.Health do
  @moduledoc """
  Higher level abstraction on top of Consul's Health API.
  """

  alias Consul.{Connection, Request, Response}

  @doc """
  List checks associated with the service provided on the path.
  """
  def list_checks(connection, service, optional_params \\ [], opts \\ []) do
    optional_params_config = %{
      :dc => :query,
      :near => :query,
      :"node-meta" => :query,
      :filter => :query,
      :ns => :query,
      :index => :query,
      :wait => :query
    }

    request =
      Request.new()
      |> Request.method(:get)
      |> Request.url("/v1/health/checks/{service}", %{
        "service" => URI.encode(service, &URI.char_unreserved?/1)
      })
      |> Request.add_optional_params(optional_params_config, optional_params)

    connection
    |> Connection.execute(request)
    |> Response.decode(opts ++ [as: %{}])
  end

  @doc """
  List nodes providing the service indicated on the path.
  """
  def list_nodes(connection, service, optional_params \\ [], opts \\ []) do
    optional_params_config = %{
      :dc => :query,
      :near => :query,
      :tag => :query,
      :"node-meta" => :query,
      :passing => :query,
      :filter => :query,
      :ns => :query,
      :index => :query,
      :wait => :query
    }

    request =
      Request.new()
      |> Request.method(:get)
      |> Request.url("/v1/health/service/{service}", %{
        "service" => URI.encode(service, &URI.char_unreserved?/1)
      })
      |> Request.add_optional_params(optional_params_config, optional_params)

    connection
    |> Connection.execute(request)
    |> Response.decode(opts ++ [as: %{}])
  end
end
