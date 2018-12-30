defmodule Aaron do
  @moduledoc """
  Markdown parser.
  """

  @aaron_vsn Mix.Project.config()[:version]

  @doc """
  Returns version.
  """
  @spec version :: String.t()
  def version, do: @aaron_vsn

  defdelegate to_html(markdown), to: Aaron.Formatters.HTML

  defdelegate parse(markdown), to: Aaron.Parser
end
