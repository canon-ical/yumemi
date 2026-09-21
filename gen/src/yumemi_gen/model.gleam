//// 生成器の内部モデル。★ から読み取った事実だけを持ち、出力の判断は emit 側に置く。

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import yumemi_gen/naming

/// 値型(types.gleam の `pub const <name>: Spec`)。
pub type Backing {
  StringValue
  IntValue
}

pub type ValueType {
  ValueType(
    /// "article_id"
    name: String,
    /// "ArticleId"
    type_name: String,
    /// "Uuid" / "Pattern" / "Text" / "Markdown" / "MarkdownText" / "Range" / "Url"
    spec: String,
    backing: Backing,
    /// `Range(min:, max:)` の両端。Range 以外は None。
    range: Option(#(Int, Int)),
  )
}

pub fn backing_of(spec: String) -> Backing {
  case spec {
    "Range" -> IntValue
    _ -> StringValue
  }
}

/// 型の参照。module は import の道(`gen/types/title` など)。
pub type TypeRef {
  TypeRef(
    module: Option(String),
    name: String,
    /// `Sealed(String, StaffKey)` のような型引数。Property でも落とさない。
    parameters: List(TypeShape),
  )
}

/// ★ の型を root の鍵照合に使う形。module は import 解決後の道。
pub type TypeShape {
  NamedShape(module: Option(String), name: String, parameters: List(TypeShape))
  TupleShape(List(TypeShape))
}

pub type RelKind {
  Has
  Held
  Link
  Multi
}

pub type PropKind {
  /// has / held / link / multi
  RelProp(kind: RelKind, target_module: String, target_type: String)
  /// 値(gen/types の型、framework の型、Int / Bool / String / Float)
  ValueProp(type_ref: TypeRef)
  /// 構成子を持つ sum(列は <prop>_kind + 各 payload)
  SumProp(type_ref: TypeRef, payloads: List(TypeRef))
}

pub type Prop {
  Prop(
    /// "muse"
    name: String,
    optional: Bool,
    repeated: Bool,
    kind: PropKind,
  )
}

/// Entity の `framework/verbs` 宣言を、生成器が検証した形で保持する。
pub type VerbRule {
  UpdateRule(name: String, fields: List(String), at: VerbGate)
  AdvanceRule(bump: VerbBump)
  DeleteWhereRule(field: String)
  CreateManyRule
  AdvanceAllRule
}

pub type VerbGate {
  AnyPhase
  Only(List(String))
}

pub type VerbBump {
  Always
  BumpUnless(from: String, to: String)
}

pub type OrderedBy {
  OrderedBy(field: String, within: List(String))
}

/// 列 1本。Field の variant 1つと SQL の 1列が同じものを指す。
pub type FieldValue {
  RelValue(target_module: String, target_type: String)
  TypeValue(type_ref: TypeRef)
  PhaseValue(module: String)
  DatetimeValue
}

pub type FieldDef {
  FieldDef(
    /// "ArticleMuse"
    name: String,
    /// "Article"
    entity_name: String,
    /// "muse_id"
    column: String,
    optional: Bool,
    repeated: Bool,
    value: FieldValue,
  )
}

pub type Entity {
  Entity(
    /// module 名。"article" / "consent_version"
    module: String,
    /// From / Field の接頭辞。module 名の PascalCase
    name: String,
    /// レコード型の名。"Article" / "ConsentVersionRow"
    type_name: String,
    /// 表の名。module 名
    table: String,
    props: List(Prop),
    fields: List(FieldDef),
    /// verb SQL だけが使う補助列(例: Sealed の `<prop>_key_id`)。
    verb_fields: List(FieldDef),
    /// Lifecycle の相。無ければ空
    phases: List(String),
    /// key 関数が返す Property の名。組なら先頭
    key_prop: String,
    /// key の列名
    key_column: String,
    /// key 関数が返す Property の全て。複合 key を先頭列へ潰さない。
    key_props: List(String),
    /// key の列の全て。`key_props` と同じ順序。
    key_columns: List(String),
    /// key / path_key の戻り型。Service Args の照合に使う。
    key_type: Option(TypeShape),
    /// key が別にある Entity の path_key 戻り型。root はどちらも受ける。
    path_key_type: Option(TypeShape),
    /// 入口での集合名(★ の `collection`)
    collection: String,
    subject: Bool,
    /// `Phase` の遷移辺。無ければ空。
    edges: List(#(String, String)),
    /// Entity に宣言された追加の verb 規則。
    verbs: List(VerbRule),
    /// 生成せず、手書きの実体へ委ねる verb 名。
    handwritten_verbs: List(String),
    /// reorder の宣言。無ければ None。
    ordered_by: Option(OrderedBy),
    /// put の鍵。無ければ空。
    upsert_key: List(String),
    /// create 時に実行側/DB が自動採番する key Property。明示が無ければ空。
    auto_key: List(String),
  )
}

/// ER の外にある module が HTTP の集合名を名乗る宣言。
pub type Collection {
  Collection(
    /// トップレベル module 名。`ledger` / `metrics`。
    module: String,
    /// 入口での集合名。`ledger_stores` / `metrics`。
    collection: String,
    /// 生成せず、手書きの実体へ委ねる verb 名。
    handwritten_verbs: List(String),
  )
}

pub fn field_by_name(entities: List(Entity), name: String) -> Option(FieldDef) {
  let all = list.flat_map(entities, fn(entity) { entity.fields })
  case list.find(all, fn(field) { field.name == name }) {
    Ok(field) -> Some(field)
    Error(_) -> None
  }
}

pub fn entity_by_name(entities: List(Entity), name: String) -> Option(Entity) {
  case list.find(entities, fn(entity) { entity.name == name }) {
    Ok(entity) -> Some(entity)
    Error(_) -> None
  }
}

pub fn entity_by_module(
  entities: List(Entity),
  module: String,
) -> Option(Entity) {
  case list.find(entities, fn(entity) { entity.module == module }) {
    Ok(entity) -> Some(entity)
    Error(_) -> None
  }
}

pub fn prop_by_name(entity: Entity, name: String) -> Option(Prop) {
  case list.find(entity.props, fn(prop) { prop.name == name }) {
    Ok(prop) -> Some(prop)
    Error(_) -> None
  }
}

pub fn field_for_prop(entity: Entity, name: String) -> Option(FieldDef) {
  let prefix = entity.name <> naming.pascal(name)
  case list.find(entity.fields, fn(field) { field.name == prefix }) {
    Ok(field) -> Some(field)
    Error(_) -> None
  }
}

pub fn has_lifecycle(entity: Entity) -> Bool {
  entity.phases != []
}

pub fn has_key(entity: Entity) -> Bool {
  entity.key_props != []
}

pub fn has_transitions(entity: Entity) -> Bool {
  entity.edges != []
}

pub fn advance_bump(entity: Entity) -> VerbBump {
  case
    list.find(entity.verbs, fn(rule) {
      case rule {
        AdvanceRule(..) -> True
        _ -> False
      }
    })
  {
    Ok(AdvanceRule(bump)) -> bump
    _ -> Always
  }
}

/// 読みの語彙。構成子は framework/query.gleam と1対1。
pub type Operand {
  OpParam(String)
  OpNum(Int)
  OpStr(String)
  OpAt(String)
  OpPhase(entity: String, variant: String)
  OpKey(entity: String)
  OpCol(String)
}

pub type Cond {
  CEq(String, Operand)
  CNe(String, Operand)
  CLt(String, Operand)
  CLe(String, Operand)
  CGt(String, Operand)
  CGe(String, Operand)
  CIn(String, Operand)
  CContains(String, Operand)
  CIsNull(String)
  CNotNull(String)
  CIsTrue(String)
  CEqOrNull(String, Operand)
  CCurrentVersion(String, String)
  CHas(String, List(Cond))
  CHasNone(String, List(Cond))
}

pub type Agg {
  ACount
  ASum(String)
  AMin(String)
  AMax(String)
  AAvg(String)
}

pub type Group {
  GByField(String)
  GBucket(String, String)
  GVia(String)
}

pub type Order {
  ONearest(String, Operand)
  OAsc(String)
  ODesc(String)
  OAscAgg(Agg)
  ODescAgg(Agg)
}

pub type Along {
  LDistance
  LRank
  LRunning(Agg)
}

pub type Limit {
  LNoLimit
  LPaged(size: Operand, after: Operand)
  LFirst(Int)
  LFirstPerGroup(Int, Group)
}

pub type Select {
  Select(
    from: String,
    join: List(String),
    where: List(Cond),
    group: List(Group),
    having: List(#(String, Agg, Operand)),
    agg: List(Agg),
    along: List(Along),
    with: List(String),
    order: List(Order),
    limit: Limit,
  )
}

pub type NamedQuery {
  NamedQuery(name: String, select: Select)
}

pub type Arg {
  Arg(name: String, type_: TypeShape)
}

/// `src/entry.gleam` の入口に宣言された認証媒体。
pub type Credential {
  SessionCredential
  ApiKeyCredential
}

pub type Admit {
  AnonymousAdmit
  AuthenticatedAdmit
}

pub type EntryServices {
  ReadOnlyServices
  AllServices
}

/// 入口が受ける subject の集合。型名は entry.gleam の構成子名をそのまま保持する。
pub type EntrySubjects {
  AnyEntrySubject
  NamedEntrySubjects(List(String))
}

pub type Entry {
  Entry(
    name: String,
    prefix: String,
    admit: Admit,
    subject: EntrySubjects,
    services: EntryServices,
    credential: Credential,
  )
}

pub type Effect {
  ReadEffect
  WriteEffect
}

/// allow の `who`。Entity は Service の第一引数へ写す主体。
pub type Subject {
  SubjectEntity(module: String, type_name: String)
  SubjectAnonymous
  SubjectParty
  SubjectSystem
}

pub type Service {
  Service(
    module: String,
    params: List(String),
    queries: List(NamedQuery),
    args: List(Arg),
    allow_module: Option(String),
    subjects: List(Subject),
    effect: Effect,
    faces: List(String),
    faces_declared: Bool,
  )
}

/// 矢印。関係 Property 1つにつき1本。
pub type Arrow {
  Arrow(
    /// "ArticleToMuse"
    name: String,
    from_entity: String,
    prop: String,
    target_entity: String,
    kind: RelKind,
    optional: Bool,
  )
}

pub type App {
  App(
    value_types: List(ValueType),
    entities: List(Entity),
    collections: List(Collection),
    services: List(Service),
    arrows: List(Arrow),
    entries: List(Entry),
    /// Entity / ER 外 module の手書き verb 名。header と警告に使う。
    handwritten_verbs: List(#(String, List(String))),
  )
}

pub fn arrow_by_name(arrows: List(Arrow), name: String) -> Option(Arrow) {
  case list.find(arrows, fn(arrow) { arrow.name == name }) {
    Ok(arrow) -> Some(arrow)
    Error(_) -> None
  }
}

pub fn value_type_by_name(
  types: List(ValueType),
  type_name: String,
) -> Option(ValueType) {
  case list.find(types, fn(value) { value.type_name == type_name }) {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}

/// 順序列の宣言上の値域。`Int` は int4 の全域、`Range` は宣言の両端。それ以外は None。
pub fn order_bounds(prop: Prop, types: List(ValueType)) -> Option(#(Int, Int)) {
  case prop.kind {
    ValueProp(type_ref: TypeRef(module: None, name: "Int", ..)) ->
      Some(#(-2_147_483_648, 2_147_483_647))
    ValueProp(type_ref: TypeRef(module: Some(path), name: name, ..)) ->
      case string.starts_with(path, "gen/types/") {
        True ->
          case value_type_by_name(types, name) {
            Some(ValueType(spec: "Range", range: Some(bounds), ..)) ->
              Some(bounds)
            _ -> None
          }
        False -> None
      }
    _ -> None
  }
}
