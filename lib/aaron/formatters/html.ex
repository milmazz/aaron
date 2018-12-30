defmodule Aaron.Formatters.HTML do
  @moduledoc """
  Transforms Aaron's parsed output into HTML
  """

  alias Aaron.Parser

  @spec to_html(String.t()) :: String.t()
  def to_html(markdown) when is_binary(markdown) do
    {:ok, ast, _, _, _, _} = Parser.parse(markdown)

    ast
    |> Enum.reduce([], fn line, acc ->
      [line |> to_html |> Enum.join() | acc]
    end)
    |> Enum.reverse()
    |> Enum.join()
  end

  def to_html({:blockquote, {:code_block, code_block}}) do
    ['<', 'blockquote', '>', to_html(code_block: code_block), '<', '/', 'blockquote', '>']
  end

  def to_html({:code_block, code_block}) do
    [
      '<',
      'pre',
      '>',
      '<',
      'code',
      '>',
      code_block,
      '\n',
      '<',
      '/',
      'code',
      '>',
      '<',
      '/',
      'pre',
      '>',
      '\n'
    ]
  end

  def to_html({:heading, [level: level]}) do
    to_html({:heading, [{:level, level} | '']})
  end

  def to_html({:heading, [{:level, level} | title]}) do
    ['<', 'h', level, '>', title, '<', '/', 'h', level, '>', '\n']
  end

  def to_html({:thematic_break, []}) do
    ['<', 'hr', ' />', '\n']
  end

  def to_html(_) do
    []
  end
end
