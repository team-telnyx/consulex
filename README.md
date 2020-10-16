# Consul

Yet another Consul Client written in Elixir, this time on top of
[`Tesla`](https://github.com/teamon/tesla).

At the time of writing, it doesn't support all APIs, just KV/Catalog/Health and
read-only APIs. On the other hand, it implements a
`Tesla.Middleware.ConsulWatch` to ease doing blocking queries to Consul.

## Installation

The package can be installed by adding `consulex` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:consulex, "~> 0.1.0"}
  ]
end
```

And then you need to pass which JSON interpreter you'll use. If that's `Jason`,
then do:

```elixir
# config/config.exs
config :consulex, json_codec: Jason
```

You can use `Poison` instead, by just substituting `Jason` by `Poison` in the
above configuration. Other libraries might need a custom `Consul.JsonCodec`
behaviour implementation.

Documentation is generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Docs can be found at
[https://hexdocs.pm/consulex](https://hexdocs.pm/consulex).

## How to use

For simple polling requests, just create a Consul connection and pass it to a
`Consul.Api` module:

```elixir
connection = Consul.Connection.new("http://consul:8500")
Consul.Api.Health.list_nodes(connection, "my_service", passing: true)
```

In order to make blocking queries, use the option `:wait`:

```elixir
connection = Consul.Connection.new("http://consul:8500", wait: 60_000)
Consul.Api.Health.list_nodes(connection, "my_service", passing: true)
```

In this case, the first execution will return immediately, while the next ones
will wait up to 60 seconds to finalize. The time passed in the `:wait` argument
is in milliseconds.

## Read YAML values from Consul KV

By default, Consulex will attempt to decode Consul KV values as JSON (using the
`JsonCodec` of your choice). If you have YAML values, add an YAML decoder that
implements the `Consul.YamlCodec` behaviour. `YamlElixir` is supported out of
the box by setting it in your config:

```elixir
# config/config.exs
config :consulex, yaml_codec: YamlElixir
```
