defmodule Consul.Api.V1.Catalog do
  @moduledoc """
  Higher level abstraction on top of Consul's Catalog API.
  """

  alias Consul.{Connection, Request, Response}

  @doc """
  List the services registered in a given datacenter.
  """
  def list_services(connection, optional_params \\ [], opts \\ []) do
    optional_params_config = %{
      :dc => :query,
      :"node-meta" => :query,
      :ns => :query,
      :index => :query,
      :wait => :query
    }

    request =
      Request.new()
      |> Request.method(:get)
      |> Request.url("/v1/catalog/services")
      |> Request.add_optional_params(optional_params_config, optional_params)

    connection
    |> Connection.execute(request)
    |> Response.decode(opts ++ [as: %{}])
  end

  @doc """
  List the nodes for a service.
  """
  def list_nodes(connection, service, optional_params \\ [], opts \\ []) do
    optional_params_config = %{
      :dc => :query,
      :tag => :query,
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
      |> Request.url("/v1/catalog/service/{service}", %{
        "service" => service
      })
      |> Request.add_optional_params(optional_params_config, optional_params)

    connection
    |> Connection.execute(request)
    |> Response.decode(opts ++ [as: %{}])
  end

  @doc """
  List datacenters.
  """
  def list_datacenters(connection, opts \\ []) do
    request =
      Request.new()
      |> Request.method(:get)
      |> Request.url("/v1/catalog/datacenters")

    connection
    |> Connection.execute(request)
    |> Response.decode(opts ++ [as: []])
  end

  @doc """
  List all available nodes.
  """
  def list_all_nodes(connection, optional_params \\ [], opts \\ []) do
    optional_params_config = %{
      :dc => :query,
      :near => :query,
      :"node-meta" => :query,
      :filter => :query,
      :index => :query,
      :wait => :query
    }

    request =
      Request.new()
      |> Request.method(:get)
      |> Request.url("/v1/catalog/nodes")
      |> Request.add_optional_params(optional_params_config, optional_params)

    connection
    |> Connection.execute(request)
    |> Response.decode(opts ++ [as: []])
  end

  @doc """
  List all available services.
  """
  def list_all_services(connection, optional_params \\ [], opts \\ []) do
    optional_params_config = %{
      :dc => :query,
      :"node-meta" => :query,
      :ns => :query,
      :index => :query,
      :wait => :query
    }

    request =
      Request.new()
      |> Request.method(:get)
      |> Request.url("/v1/catalog/services")
      |> Request.add_optional_params(optional_params_config, optional_params)

    connection
    |> Connection.execute(request)
    |> Response.decode(opts ++ [as: []])
  end

  @doc """
  List services at a node.
  """
  def list_node_services(connection, node, optional_params \\ [], opts \\ []) do
    optional_params_config = %{
      :dc => :query,
      :filter => :query,
      :ns => :query,
      :index => :query,
      :wait => :query
    }

    request =
      Request.new()
      |> Request.method(:get)
      |> Request.url("/v1/catalog/node/{node}", %{
        "node" => node
      })
      |> Request.add_optional_params(optional_params_config, optional_params)

    connection
    |> Connection.execute(request)
    |> Response.decode(opts ++ [as: %{}])
  end
end
