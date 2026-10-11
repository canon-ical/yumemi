//// Convert the supported docs/api-v1.md subset into static front Element expressions.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub type Document {
  Document(nodes: List(String), tables: List(String))
}

pub fn parse(source: String) -> Result(Document, Nil) {
  source
  |> string.replace("\r\n", "\n")
  |> string.split("\n")
  |> parse_blocks([], [], 1)
}

pub fn helpers(document: Document) -> String {
  let rendered = string.join(list.append(document.nodes, document.tables), "\n")
  let helpers = [
    #("heading1", heading_helper(1)),
    #("heading2", heading_helper(2)),
    #("heading3", heading_helper(3)),
    #("heading4", heading_helper(4)),
    #("heading5", heading_helper(5)),
    #("heading6", heading_helper(6)),
    #(
      "paragraph",
      "fn paragraph(children: List(el.Element(Nil))) -> el.Element(Nil) {\n"
        <> "  html.p(sketch_css.class([style.body, style.ink]), [], children)\n"
        <> "}",
    ),
    #(
      "inline_code",
      "fn inline_code(value: String) -> el.Element(Nil) {\n"
        <> "  html.code(sketch_css.class([style.body, style.ink]), [], [el.text(value)])\n"
        <> "}",
    ),
    #(
      "fenced_code",
      "fn fenced_code(value: String) -> el.Element(Nil) {\n"
        <> "  html.pre(sketch_css.class([style.body, style.ink]), [], [\n"
        <> "    html.code(sketch_css.class([style.body, style.ink]), [], [el.text(value)]),\n"
        <> "  ])\n"
        <> "}",
    ),
    #(
      "unordered_list",
      "fn unordered_list(items: List(List(el.Element(Nil)))) -> el.Element(Nil) {\n"
        <> "  html.ul(sketch_css.class([style.body, style.ink]), [], list.map(items, fn(children) {\n"
        <> "    html.li(sketch_css.class([style.body, style.ink]), [], children)\n"
        <> "  }))\n"
        <> "}",
    ),
    #(
      "table_row",
      "fn table_row(cells: List(el.Element(Nil))) -> el.Element(Nil) {\n"
        <> "  html.tr(sketch_css.class([style.body, style.ink]), [], cells)\n"
        <> "}",
    ),
    #(
      "header_cell",
      "fn header_cell(children: List(el.Element(Nil))) -> el.Element(Nil) {\n"
        <> "  html.th(sketch_css.class([style.body, style.ink]), [], children)\n"
        <> "}",
    ),
    #(
      "data_cell",
      "fn data_cell(children: List(el.Element(Nil))) -> el.Element(Nil) {\n"
        <> "  html.td(sketch_css.class([style.body, style.ink]), [], children)\n"
        <> "}",
    ),
  ]
  let used_helpers =
    list.filter_map(helpers, fn(helper) {
      let #(name, definition) = helper
      case string.contains(rendered, name <> "(") {
        True -> Ok(definition)
        False -> Error(Nil)
      }
    })
  string.join(used_helpers, "\n\n") <> "\n"
}

fn parse_blocks(
  lines: List(String),
  nodes: List(String),
  tables: List(String),
  next_table: Int,
) -> Result(Document, Nil) {
  case lines {
    [] -> Ok(Document(nodes: list.reverse(nodes), tables: list.reverse(tables)))
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case trimmed == "" {
        True -> parse_blocks(rest, nodes, tables, next_table)
        False ->
          parse_nonblank(trimmed, [line, ..rest], nodes, tables, next_table)
      }
    }
  }
}

fn parse_nonblank(
  line: String,
  lines: List(String),
  nodes: List(String),
  tables: List(String),
  next_table: Int,
) -> Result(Document, Nil) {
  case string.starts_with(line, "```") {
    True ->
      case fenced_body(list.drop(lines, 1), []) {
        Ok(#(body, remaining)) ->
          parse_blocks(
            remaining,
            ["fenced_code(" <> string.inspect(body) <> ")", ..nodes],
            tables,
            next_table,
          )
        Error(_) -> Error(Nil)
      }
    False ->
      case string.starts_with(line, "#") {
        True ->
          case heading(line) {
            Some(#(level, title)) ->
              parse_blocks(
                list.drop(lines, 1),
                [
                  "heading"
                    <> int.to_string(level)
                    <> "("
                    <> string.inspect(title)
                    <> ")",
                  ..nodes
                ],
                tables,
                next_table,
              )
            None -> Error(Nil)
          }
        False ->
          case string.starts_with(line, "|") {
            True ->
              case read_table(lines, []) {
                Ok(#(rows, remaining)) ->
                  case table_definition(rows, next_table) {
                    Ok(definition) ->
                      parse_blocks(
                        remaining,
                        ["table_" <> int.to_string(next_table) <> "()", ..nodes],
                        [definition, ..tables],
                        next_table + 1,
                      )
                    Error(_) -> Error(Nil)
                  }
                Error(_) -> Error(Nil)
              }
            False ->
              case list_marker(line) {
                Some(_) ->
                  case read_list(lines, []) {
                    Ok(#(items, remaining)) ->
                      case list_items_expression(items) {
                        Ok(expression) ->
                          parse_blocks(
                            remaining,
                            ["unordered_list(" <> expression <> ")", ..nodes],
                            tables,
                            next_table,
                          )
                        Error(_) -> Error(Nil)
                      }
                    Error(_) -> Error(Nil)
                  }
                None ->
                  case unsupported_block(line) {
                    True -> Error(Nil)
                    False -> {
                      let #(text, remaining) = paragraph_lines(lines, [])
                      case inline_nodes(text) {
                        Ok(children) ->
                          parse_blocks(
                            remaining,
                            ["paragraph(" <> children <> ")", ..nodes],
                            tables,
                            next_table,
                          )
                        Error(_) -> Error(Nil)
                      }
                    }
                  }
              }
          }
      }
  }
}

fn heading(line: String) -> Option(#(Int, String)) {
  heading_prefix(line, [
    #("###### ", 6),
    #("##### ", 5),
    #("#### ", 4),
    #("### ", 3),
    #("## ", 2),
    #("# ", 1),
  ])
}

fn heading_prefix(
  line: String,
  prefixes: List(#(String, Int)),
) -> Option(#(Int, String)) {
  case prefixes {
    [] -> None
    [#(prefix, level), ..rest] ->
      case string.starts_with(line, prefix) {
        True -> {
          let parts = string.split(line, prefix)
          case parts {
            ["", ..tail] ->
              Some(#(level, string.join(tail, prefix) |> string.trim))
            _ -> None
          }
        }
        False -> heading_prefix(line, rest)
      }
  }
}

fn fenced_body(
  lines: List(String),
  reversed: List(String),
) -> Result(#(String, List(String)), Nil) {
  case lines {
    [] -> Error(Nil)
    [line, ..rest] ->
      case string.trim(line) == "```" {
        True -> Ok(#(string.join(list.reverse(reversed), "\n"), rest))
        False -> fenced_body(rest, [line, ..reversed])
      }
  }
}

fn read_table(
  lines: List(String),
  reversed_rows: List(List(String)),
) -> Result(#(List(List(String)), List(String)), Nil) {
  case lines {
    [] -> Ok(#(list.reverse(reversed_rows), []))
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case string.starts_with(trimmed, "|") {
        True ->
          case table_cells(trimmed) {
            Some(cells) -> read_table(rest, [cells, ..reversed_rows])
            None -> Error(Nil)
          }
        False -> Ok(#(list.reverse(reversed_rows), lines))
      }
    }
  }
}

fn table_cells(line: String) -> Option(List(String)) {
  let pieces = string.split(line, "|")
  case list.first(pieces), list.last(pieces) {
    Ok(first), Ok(last) if first == "" && last == "" -> {
      let cells = pieces |> list.drop(1) |> list.take(list.length(pieces) - 2)
      case cells {
        [] -> None
        _ -> Some(list.map(cells, string.trim))
      }
    }
    _, _ -> None
  }
}

fn table_definition(
  rows: List(List(String)),
  index: Int,
) -> Result(String, Nil) {
  case rows {
    [headers, separator, ..body] ->
      case
        headers != []
        && list.length(headers) == list.length(separator)
        && list.all(separator, separator_cell)
        && list.all(body, fn(row) { list.length(row) == list.length(headers) })
      {
        False -> Error(Nil)
        True ->
          case cells_expression(headers, "header_cell") {
            Error(_) -> Error(Nil)
            Ok(header_cells) ->
              case list.try_map(body, data_row_expression) {
                Error(_) -> Error(Nil)
                Ok(body_rows) -> {
                  let table_name = "table_" <> int.to_string(index)
                  Ok(
                    "fn "
                    <> table_name
                    <> "() -> el.Element(Nil) {\n"
                    <> "  html.table(sketch_css.class([style.body, style.ink]), [], [\n"
                    <> "    html.thead(sketch_css.class([style.body, style.ink]), [], [\n"
                    <> "      table_row([\n"
                    <> indent_join(header_cells, "        ")
                    <> "\n      ]),\n"
                    <> "    ]),\n"
                    <> "    html.tbody(sketch_css.class([style.body, style.ink]), [], [\n"
                    <> indent_join(body_rows, "      ")
                    <> "\n    ]),\n"
                    <> "  ])\n"
                    <> "}",
                  )
                }
              }
          }
      }
    _ -> Error(Nil)
  }
}

fn separator_cell(value: String) -> Bool {
  let compact =
    value
    |> string.replace("-", "")
    |> string.replace(":", "")
    |> string.trim
  string.contains(value, "-") && compact == ""
}

fn cells_expression(
  cells: List(String),
  constructor: String,
) -> Result(List(String), Nil) {
  list.try_map(cells, fn(cell) {
    case inline_nodes(cell) {
      Ok(children) -> Ok(constructor <> "(" <> children <> ")")
      Error(_) -> Error(Nil)
    }
  })
}

fn data_row_expression(cells: List(String)) -> Result(String, Nil) {
  case cells_expression(cells, "data_cell") {
    Ok(expressions) ->
      Ok(
        "table_row([\n" <> indent_join(expressions, "        ") <> "\n      ])",
      )
    Error(_) -> Error(Nil)
  }
}

fn indent_join(values: List(String), indentation: String) -> String {
  values
  |> list.map(fn(value) { indentation <> value })
  |> string.join(",\n")
}

fn read_list(
  lines: List(String),
  reversed_items: List(String),
) -> Result(#(List(String), List(String)), Nil) {
  case lines {
    [] -> Ok(#(list.reverse(reversed_items), []))
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case list_marker(trimmed) {
        Some(marker) ->
          case line == trimmed {
            True ->
              case drop_prefix(trimmed, marker) {
                Some(item) -> read_list(rest, [item, ..reversed_items])
                None -> Error(Nil)
              }
            False -> Error(Nil)
          }
        None -> Ok(#(list.reverse(reversed_items), lines))
      }
    }
  }
}

fn list_marker(line: String) -> Option(String) {
  case drop_prefix(line, "- ") {
    Some(_) -> Some("- ")
    None ->
      case drop_prefix(line, "* ") {
        Some(_) -> Some("* ")
        None ->
          case drop_prefix(line, "+ ") {
            Some(_) -> Some("+ ")
            None -> None
          }
      }
  }
}

fn drop_prefix(value: String, prefix: String) -> Option(String) {
  case string.starts_with(value, prefix) {
    True -> Some(string.drop_start(value, 2) |> string.trim)
    False -> None
  }
}

fn list_items_expression(items: List(String)) -> Result(String, Nil) {
  case list.try_map(items, inline_nodes) {
    Ok(expressions) -> Ok("[" <> string.join(expressions, ", ") <> "]")
    Error(_) -> Error(Nil)
  }
}

fn paragraph_lines(
  lines: List(String),
  reversed: List(String),
) -> #(String, List(String)) {
  case lines {
    [] -> #(string.join(list.reverse(reversed), " "), [])
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case trimmed == "" || block_start(trimmed) {
        True -> #(string.join(list.reverse(reversed), " "), lines)
        False -> paragraph_lines(rest, [trimmed, ..reversed])
      }
    }
  }
}

fn block_start(line: String) -> Bool {
  string.starts_with(line, "#")
  || string.starts_with(line, "|")
  || string.starts_with(line, "```")
  || list_marker(line) != None
  || unsupported_block(line)
}

fn unsupported_block(line: String) -> Bool {
  string.starts_with(line, ">") || horizontal_rule(line) || ordered_list(line)
}

fn horizontal_rule(line: String) -> Bool {
  let compact = string.replace(line, " ", "")
  compact == "---" || compact == "***" || compact == "___"
}

fn ordered_list(line: String) -> Bool {
  case string.split(line, ". ") {
    [number, ..rest] if rest != [] ->
      case int.parse(number) {
        Ok(_) -> True
        Error(_) -> False
      }
    _ -> False
  }
}

fn inline_nodes(value: String) -> Result(String, Nil) {
  inline_segments(string.split(value, "`"), False, [])
}

fn inline_segments(
  segments: List(String),
  in_code: Bool,
  reversed_nodes: List(String),
) -> Result(String, Nil) {
  case segments {
    [] -> Error(Nil)
    [segment] ->
      case inline_segment(segment, in_code, reversed_nodes) {
        Ok(nodes) ->
          case in_code {
            True -> Error(Nil)
            False -> Ok("[" <> string.join(list.reverse(nodes), ", ") <> "]")
          }
        Error(_) -> Error(Nil)
      }
    [segment, ..rest] ->
      case inline_segment(segment, in_code, reversed_nodes) {
        Ok(nodes) -> inline_segments(rest, !in_code, nodes)
        Error(_) -> Error(Nil)
      }
  }
}

fn inline_segment(
  segment: String,
  in_code: Bool,
  reversed_nodes: List(String),
) -> Result(List(String), Nil) {
  case in_code {
    True ->
      Ok(["inline_code(" <> string.inspect(segment) <> ")", ..reversed_nodes])
    False ->
      case unsupported_inline(segment) {
        True -> Error(Nil)
        False ->
          case segment == "" {
            True -> Ok(reversed_nodes)
            False ->
              Ok([
                "el.text(" <> string.inspect(segment) <> ")",
                ..reversed_nodes
              ])
          }
      }
  }
}

fn unsupported_inline(value: String) -> Bool {
  string.contains(value, "[")
  || string.contains(value, "]")
  || string.contains(value, "<")
  || string.contains(value, ">")
  || string.contains(value, "\\")
  || string.contains(value, "**")
  || string.contains(value, "__")
  || string.contains(value, "~~")
  || paired_marker(value, "*")
  || paired_marker(value, "_")
}

fn paired_marker(value: String, marker: String) -> Bool {
  case string.split(value, marker) {
    [_, inside, ..] ->
      string.trim(inside) != ""
      && !string.starts_with(inside, " ")
      && !string.ends_with(inside, " ")
    _ -> False
  }
}

fn heading_helper(level: Int) -> String {
  "fn heading"
  <> int.to_string(level)
  <> "(value: String) -> el.Element(Nil) {\n"
  <> "  html.h"
  <> int.to_string(level)
  <> "(sketch_css.class([style.heading, style.ink]), [], [el.text(value)])\n"
  <> "}"
}
