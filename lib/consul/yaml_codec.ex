defmodule Consul.YamlCodec do
  @type yaml_value :: nil | true | false | list | float | integer | String.t() | map
  
  @callback read_from_string(iodata) :: {:ok, yaml_value} | {:error, term}

  def read_from_string(iodata) do
    case yaml_codec() do
      nil ->
        {:error, :not_implemented}
      
      mod ->
        mod.read_from_string(iodata)
    end
  end

  defp yaml_codec(), do: Application.get_env(:consulex, :yaml_codec)
end
