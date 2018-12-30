defmodule Aaron.CLI do
  @moduledoc """
  CLI module for Aaron.
  """

  @doc """
  Handles command line parsing for the CLI (escript) version.
  """
  def main(argv) do
    argv
    |> parse_args()
    |> process()
  end

  def parse_args(argv) do
    switches = [help: :boolean, version: :boolean]
    aliases = [h: :help, v: :version]

    parsed = OptionParser.parse(argv, switches: switches, aliases: aliases)

    case parsed do
      {[{switch, true}], _, _} when switch in [:version, :help] ->
        switch

      {_, [filename], _} ->
        filename

      _ ->
        :help
    end
  end

  defp process(:help) do
    IO.puts("Show help...")
  end

  defp process(:version) do
    IO.puts("Aaron v#{Aaron.version()}")
  end

  defp process(filename) do
    if File.exists?(filename) do
      filename
      |> File.read!()
      |> Aaron.to_html()
      |> IO.puts()
    else
      IO.puts(:stderr, "File does not exist")
    end
  end
end
