defmodule AaronTest do
  use ExUnit.Case
  doctest Aaron

  # The `spec_tests.json` file was generated using the source from:
  #
  # https://github.com/commonmark/CommonMark
  #
  # and then you need to execute:
  #
  # python3 test/spec_tests.py --dump-tests > spec_tests.json
  #
  # to extract the raw test data from the spec in JSON format.
  spec_tests =
    ["fixtures", "spec_tests.json"]
    |> Path.join()
    |> Path.expand(__DIR__)
    |> File.read!()
    |> Jason.decode!()

  for %{"html" => html, "markdown" => markdown, "section" => section, "example" => example} <-
        spec_tests,
      section in ["ATX headings", "Thematic breaks"] do
    test "#{section}: #{example}" do
      assert Aaron.to_html(unquote(markdown)) == unquote(html)
    end
  end
end
