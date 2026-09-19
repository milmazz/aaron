defmodule Aaron.Formatters.HTML do
  @moduledoc """
  Transforms Aaron's parsed output into HTML.

  A port of commonmark.js's HTML renderer: it walks the AST emitting
  entering/exiting events per node and accumulates the output.
  """

  alias Aaron.Parser

  @container_types [
    :document,
    :block_quote,
    :list,
    :item,
    :paragraph,
    :heading,
    :emph,
    :strong,
    :link,
    :image
  ]

  @spec to_html(String.t()) :: String.t()
  def to_html(markdown) when is_binary(markdown) do
    {:ok, doc} = Parser.parse(markdown)
    render(doc)
  end

  @doc false
  def render(doc) do
    state = %{out: [], last: "\n", disable_tags: 0}
    state = walk(doc, [], state)
    IO.iodata_to_binary(state.out)
  end

  # Emit an entering event for every node; container nodes also get an
  # exiting event after their children.
  defp walk(node, ancestors, state) do
    state = handle(node, true, ancestors, state)

    if node.type in @container_types do
      state =
        Enum.reduce(node.children, state, fn child, acc ->
          walk(child, [node | ancestors], acc)
        end)

      handle(node, false, ancestors, state)
    else
      state
    end
  end

  # -- Node handlers ------------------------------------------------------------

  defp handle(%{type: :document}, _entering, _ancestors, state), do: state

  defp handle(%{type: :text} = node, _entering, _ancestors, state),
    do: out(state, node.literal)

  defp handle(%{type: :softbreak}, _entering, _ancestors, state), do: lit(state, "\n")

  defp handle(%{type: :linebreak}, _entering, _ancestors, state),
    do: state |> tag("br", [], true) |> cr()

  defp handle(%{type: :emph}, entering, _ancestors, state),
    do: tag(state, if(entering, do: "em", else: "/em"))

  defp handle(%{type: :strong}, entering, _ancestors, state),
    do: tag(state, if(entering, do: "strong", else: "/strong"))

  defp handle(%{type: :html_inline} = node, _entering, _ancestors, state),
    do: lit(state, node.literal)

  defp handle(%{type: :html_block} = node, _entering, _ancestors, state),
    do: state |> cr() |> lit(node.literal) |> cr()

  defp handle(%{type: :code} = node, _entering, _ancestors, state) do
    state
    |> tag("code")
    |> out(node.literal)
    |> tag("/code")
  end

  defp handle(%{type: :code_block} = node, _entering, _ancestors, state) do
    info_words =
      case node.info do
        nil -> []
        "" -> []
        info -> String.split(info, ~r/\s+/)
      end

    attrs =
      case info_words do
        [first | _] when first != "" ->
          class = esc(first)
          class = if String.starts_with?(class, "language-"), do: class, else: "language-" <> class
          [{"class", class}]

        _ ->
          []
      end

    state
    |> cr()
    |> tag("pre")
    |> tag("code", attrs)
    |> out(node.literal)
    |> tag("/code")
    |> tag("/pre")
    |> cr()
  end

  defp handle(%{type: :thematic_break}, _entering, _ancestors, state),
    do: state |> cr() |> tag("hr", [], true) |> cr()

  defp handle(%{type: :heading} = node, entering, _ancestors, state) do
    tagname = "h" <> Integer.to_string(node.level)

    if entering do
      state |> cr() |> tag(tagname)
    else
      state |> tag("/" <> tagname) |> cr()
    end
  end

  defp handle(%{type: :paragraph}, entering, ancestors, state) do
    grandparent =
      case ancestors do
        [_parent, grandparent | _] -> grandparent
        _ -> nil
      end

    if grandparent != nil and grandparent.type == :list and grandparent.list_data.tight do
      state
    else
      if entering do
        state |> cr() |> tag("p")
      else
        state |> tag("/p") |> cr()
      end
    end
  end

  defp handle(%{type: :block_quote}, entering, _ancestors, state) do
    if entering do
      state |> cr() |> tag("blockquote") |> cr()
    else
      state |> cr() |> tag("/blockquote") |> cr()
    end
  end

  defp handle(%{type: :list} = node, entering, _ancestors, state) do
    tagname = if node.list_data.type == :bullet, do: "ul", else: "ol"

    if entering do
      start = node.list_data.start

      attrs =
        if start != nil and start != 1 do
          [{"start", Integer.to_string(start)}]
        else
          []
        end

      state |> cr() |> tag(tagname, attrs) |> cr()
    else
      state |> cr() |> tag("/" <> tagname) |> cr()
    end
  end

  defp handle(%{type: :item}, entering, _ancestors, state) do
    if entering do
      tag(state, "li")
    else
      state |> tag("/li") |> cr()
    end
  end

  defp handle(%{type: :link} = node, entering, _ancestors, state) do
    if entering do
      attrs = [{"href", esc(node.destination)}]
      attrs = if node.title not in [nil, ""], do: attrs ++ [{"title", esc(node.title)}], else: attrs
      tag(state, "a", attrs)
    else
      tag(state, "/a")
    end
  end

  defp handle(%{type: :image} = node, entering, _ancestors, state) do
    if entering do
      state =
        if state.disable_tags == 0 do
          lit(state, "<img src=\"" <> esc(node.destination) <> "\" alt=\"")
        else
          state
        end

      %{state | disable_tags: state.disable_tags + 1}
    else
      state = %{state | disable_tags: state.disable_tags - 1}

      if state.disable_tags == 0 do
        state =
          if node.title not in [nil, ""] do
            lit(state, "\" title=\"" <> esc(node.title))
          else
            state
          end

        lit(state, "\" />")
      else
        state
      end
    end
  end

  # -- Output helpers ------------------------------------------------------------

  defp lit(state, s), do: %{state | out: [state.out, s], last: s}

  defp cr(state) do
    if state.last == "\n", do: state, else: lit(state, "\n")
  end

  defp out(state, s), do: lit(state, esc(s))

  defp tag(state, name, attrs \\ [], selfclosing \\ false) do
    if state.disable_tags > 0 do
      state
    else
      attr_string =
        Enum.map_join(attrs, fn {key, value} -> " " <> key <> "=\"" <> value <> "\"" end)

      s = "<" <> name <> attr_string <> if(selfclosing, do: " /", else: "") <> ">"
      %{state | out: [state.out, s], last: ">"}
    end
  end

  defp esc(s) do
    s
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
