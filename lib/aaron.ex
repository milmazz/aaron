defmodule Aaron do
  @moduledoc """
  Markdown parser.
  """
  defdelegate to_html(markdown), to: Aaron.Formatters.HTML

  defdelegate parse(markdown), to: Aaron.Parser
end
