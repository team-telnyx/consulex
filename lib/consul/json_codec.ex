defmodule Consul.JsonCodec do
  @type json_value :: nil | true | false | list | float | integer | String.t() | map
  
  @callback decode(iodata) :: {:ok, json_value} | {:error, term}
  @callback decode(iodata, keyword) :: {:ok, json_value} | {:error, term}

  def decode(iodata), do: json_codec().decode(iodata)
  def decode(iodata, opts), do: json_codec().decode(iodata, opts)

  defp json_codec(), do: Application.fetch_env!(:consulex, :json_codec)
end
