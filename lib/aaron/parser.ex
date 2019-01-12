defmodule Aaron.Parser do
  import NimbleParsec

  # block := block_quote | list | code_block | paragraph | heading | thematic_break | html_block | custom_block
  # inline := text | softbreak | linebreak | code | emph | strong | link |image | html_inline | custom_inline
  #
  # Special codepoints
  @newline 0x000A
  @carriage_return 0x000D
  @space 0x0020
  @tab 0x009
  @line_tabulation 0x000B
  @form_feed 0x000C

  # A line ending is a newline (U+000A), a carriage return (U+000D) not
  # followed by a newline, or a carriage return and a following newline.
  line_ending =
    choice([
      utf8_char([@newline]),
      [@carriage_return] |> utf8_char() |> optional(utf8_char([@newline]))
    ])

  # A line containing no characters, or a line containing only spaces (U+0020)
  # or tabs (U+0009), is called a blank line.
  blank_line =
    [@space, @tab]
    |> utf8_char()
    |> times(min: 1)

  # A whitespace character is a space (U+0020), tab (U+0009), newline (U+000A),
  # line tabulation (U+000B), form feed (U+000C), or carriage return (U+000D).
  whitespace_character =
    utf8_char([
      @space,
      @tab,
      @newline,
      @line_tabulation,
      @form_feed,
      @carriage_return
    ])

  # Whitespace is a sequence of one or more whitespace characters.
  # whitespace = times(whitespace_character, min: 1)

  non_indented_space =
    [@space]
    |> utf8_char()
    |> times(max: 3)

  indented_space =
    [@space]
    |> utf8_char()
    |> times(4)

  starts_with_tab =
    non_indented_space
    |> optional()
    |> ignore()
    |> utf8_char([@tab])

  indented_line = choice([indented_space, starts_with_tab])

  code_block =
    indented_line
    |> ignore()
    |> ascii_string([not: ?\n], min: 1)
    |> unwrap_and_tag(:code_block)

  block_quote =
    [?>]
    |> ascii_char()
    |> ignore()
    |> parsec(:parse)
    |> unwrap_and_tag(:block_quote)

  spacechar = utf8_char([@space, @tab])
  sp = optional(times(spacechar, min: 1))

  # Section 4.1: Thematic breaks
  #
  # A line consisting of 0-3 spaces of indentation, followed by a sequence of
  # three or more matching -, _, or * characters, each followed optionally by
  # any number of spaces, forms a thematic break.
  thematic_break =
    non_indented_space
    |> optional()
    |> choice([
      times([?-] |> ascii_char() |> concat(sp), min: 3),
      times([?_] |> ascii_char() |> concat(sp), min: 3),
      times([?*] |> ascii_char() |> concat(sp), min: 3)
    ])
    |> ascii_char([?\n])
    |> ignore()
    |> tag(:thematic_break)

  # Section 4.2: ATX headings
  #
  # An ATX heading consists of a string of characters, parsed as inline
  # content, between an opening sequence of 1–6 unescaped # characters and an
  # optional closing sequence of any number of unescaped # characters. The
  # opening sequence of # characters must be followed by a space or by the end
  # of line. The optional closing sequence of #s must be preceded by a space
  # and may be followed by spaces only. The opening # character may be indented
  # 0-3 spaces. The raw contents of the heading are stripped of leading and
  # trailing spaces before being parsed as inline content. The heading level is
  # equal to the number of # characters in the opening sequence.
  atx_prefix =
    non_indented_space
    |> optional()
    |> ignore()
    |> ascii_char([?#])
    |> times(min: 1, max: 6)
    |> reduce(:length)
    |> unwrap_and_tag(:level)

  atx_suffix =
    [?\s]
    |> ascii_string(min: 1)
    |> times(ascii_char([?#]), min: 1)
    |> concat(sp)
    |> ignore()

  atx_end = [ascii_char([?\n]), eos()] |> choice() |> ignore()

  atx_content =
    choice([
      [?\\] |> ascii_char() |> ignore() |> ascii_char([?#]),
      ascii_char(not: ?\n)
    ])

  heading =
    atx_prefix
    |> choice([
      atx_end,
      [?\s]
      |> ascii_string(min: 1)
      |> ignore()
      |> repeat(" #" |> string() |> lookahead_not() |> concat(atx_content))
      |> choice([
        atx_end,
        concat(atx_suffix, atx_end),
        atx_content |> times(min: 1) |> concat(atx_end)
      ])
      |> reduce(:trim)
    ])
    |> tag(:heading)

  defp trim(line), do: line |> List.to_string() |> String.trim()

  block =
    choice([
      block_quote,
      thematic_break,
      code_block,
      heading
    ])

  defparsec(:parse, repeat_while(block, {:eof, []}))

  ## Helpers
  defp eof("", context, _, _), do: {:halt, context}
  defp eof(_, context, _, _), do: {:cont, context}
end
