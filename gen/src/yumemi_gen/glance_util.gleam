//// glance の木を覗くための小道具。glance は定義を逆順に積むので、順を戻すのもここ。

import glance
import gleam/list
import gleam/option.{type Option, None, Some}

/// glance は Module の各リストへ先頭から積むので、宣言順に戻す。
pub fn in_order(module: glance.Module) -> glance.Module {
  glance.Module(
    imports: list.reverse(module.imports),
    custom_types: list.reverse(module.custom_types),
    type_aliases: list.reverse(module.type_aliases),
    constants: list.reverse(module.constants),
    functions: list.reverse(module.functions),
  )
}

/// 構成子の名。module 修飾は落とす(`q.Select` -> "Select")。
pub fn ctor_name(expression: glance.Expression) -> Option(String) {
  case expression {
    glance.Call(function: function, ..) -> ctor_name(function)
    glance.FieldAccess(label: label, ..) -> Some(label)
    glance.Variable(name: name, ..) -> Some(name)
    _ -> None
  }
}

/// 構成子の module 修飾(`article.Published` -> "article")。
pub fn ctor_module(expression: glance.Expression) -> Option(String) {
  case expression {
    glance.Call(function: function, ..) -> ctor_module(function)
    glance.FieldAccess(container: glance.Variable(name: name, ..), ..) ->
      Some(name)
    _ -> None
  }
}

/// 呼び出しの引数。ラベルは無視して順に返す。
pub fn args(expression: glance.Expression) -> List(glance.Expression) {
  case expression {
    glance.Call(arguments: arguments, ..) ->
      list.filter_map(arguments, fn(field) {
        case field {
          glance.LabelledField(item: item, ..) -> Ok(item)
          glance.UnlabelledField(item: item) -> Ok(item)
          glance.ShorthandField(..) -> Error(Nil)
        }
      })
    _ -> []
  }
}

/// ラベル付き引数を名で引く。
pub fn labelled(
  expression: glance.Expression,
  label: String,
) -> Option(glance.Expression) {
  case expression {
    glance.Call(arguments: arguments, ..) ->
      case
        list.find_map(arguments, fn(field) {
          case field {
            glance.LabelledField(label: found, item: item, ..) if found == label ->
              Ok(item)
            _ -> Error(Nil)
          }
        })
      {
        Ok(item) -> Some(item)
        Error(_) -> None
      }
    _ -> None
  }
}

pub fn list_elements(expression: glance.Expression) -> List(glance.Expression) {
  case expression {
    glance.List(elements: elements, ..) -> elements
    _ -> []
  }
}

pub fn int_value(expression: glance.Expression) -> Option(String) {
  case expression {
    glance.Int(value: value, ..) -> Some(value)
    _ -> None
  }
}

pub fn string_value(expression: glance.Expression) -> Option(String) {
  case expression {
    glance.String(value: value, ..) -> Some(value)
    _ -> None
  }
}

/// 型注釈の名(`q.Select(P)` -> "Select")。
pub fn type_name(annotation: glance.Type) -> Option(String) {
  case annotation {
    glance.NamedType(name: name, ..) -> Some(name)
    _ -> None
  }
}

pub fn type_module(annotation: glance.Type) -> Option(String) {
  case annotation {
    glance.NamedType(module: module, ..) -> module
    _ -> None
  }
}

pub fn type_params(annotation: glance.Type) -> List(glance.Type) {
  case annotation {
    glance.NamedType(parameters: parameters, ..) -> parameters
    _ -> []
  }
}

pub fn variant_field_label(field: glance.VariantField) -> Option(String) {
  case field {
    glance.LabelledVariantField(label: label, ..) -> Some(label)
    glance.UnlabelledVariantField(..) -> None
  }
}

pub fn variant_field_type(field: glance.VariantField) -> glance.Type {
  case field {
    glance.LabelledVariantField(item: item, ..) -> item
    glance.UnlabelledVariantField(item: item) -> item
  }
}

pub fn find_custom_type(
  module: glance.Module,
  name: String,
) -> Option(glance.CustomType) {
  case
    list.find(module.custom_types, fn(definition) {
      definition.definition.name == name
    })
  {
    Ok(definition) -> Some(definition.definition)
    Error(_) -> None
  }
}

pub fn find_constant(
  module: glance.Module,
  name: String,
) -> Option(glance.Constant) {
  case
    list.find(module.constants, fn(definition) {
      definition.definition.name == name
    })
  {
    Ok(definition) -> Some(definition.definition)
    Error(_) -> None
  }
}

pub fn find_function(
  module: glance.Module,
  name: String,
) -> Option(glance.Function) {
  case
    list.find(module.functions, fn(definition) {
      definition.definition.name == name
    })
  {
    Ok(definition) -> Some(definition.definition)
    Error(_) -> None
  }
}
