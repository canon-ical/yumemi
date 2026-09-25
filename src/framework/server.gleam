//// back の宣言 ── 生成器が app の `src/server.gleam` の const を読み、`src/gen/registry.mjs` /
//// `http_runtime.mjs` / `shell.mjs` / `queue_runtime.mjs` / `cron_runtime.mjs` を書く(0.11.1、WGy)。
////
//// 置く const は 5 つ。どれも無くてよい(無ければ空の表)。
////
//// - `pub const routes: List(Route)` ── Service の (method, path) の上書き。導出規則(entry の prefix と
////   Entity / Args の型)と同じ行は書かない。公開の URL(REST v1、鍵の発行)は導出に寄せず、ここで固定する
//// - `pub const aliases: List(Alias)` ── 同じ Service(または attached の口)の 2 本目の口(REST v1 の別名)
//// - `pub const attached: List(Attached)` ── Service でない HTTP の口(session・blob・media・socket など)。
////   面の `api.gleam` の `attached` 表も、ここから書く
//// - `pub const cron: List(Cron)` ── 式と、その式で回す仕事
//// - `pub const durable_objects: List(DurableObject)` ── class 名と、実装を持つ ★ の adapter
//// - `pub const hooks: List(Hook)` ── 宣言から導けない業務の行の口。生成物が import する ★ は、ここに名を
////   書いたものだけ
//// - `pub const reads: List(ManualRead)` ── 手書きの SQL で引く読み。生成器は型付きの口と runtime の振り分けを書き、
////   SQL と行の写し(hook)は ★
//// - `pub const roots: List(RootShape)` ── root の導出(allow の Entity と Args の key の型)と違う Service の root
//// - `pub const storage: List(Storage)` ── Entity の器と列の写像。導出(Neon の `app.<module>`、Property 名 =
////   列名、payload の無い sum は text、record と List は jsonb)と違う Entity の Property だけを書く
////
//// Service は名(module の名、`article_publish`)で指す ── Service の値は型引数が Service ごとに違い、
//// 1 つの List に並ばないため。名が Service に無ければ生成器が exit 4 で名指しする。
//// path の変数は `:name`(registry の綴り)。

pub type Method {
  Get
  Post
  Put
  Delete
}

/// 口が受ける媒体。entry の `Credential` と同じ 2 値(`ApiKey` の per_minute は entry が持つ)。
pub type Credential {
  Session
  ApiKey
}

/// Service でない口の主体。`Anyone` は未ログインを通し、`Party` は session の party を要る。
pub type Who {
  Anyone
  Party
}

pub type Route {
  /// 導出の (method, path) をこれに替える。媒体は導出どおり(`Session` の入口)。
  Route(service: String, method: Method, path: String)
  /// 媒体を明示する口。`ApiKey` なら REST v1 の入口だけが持つ。
  RouteVia(
    service: String,
    method: Method,
    path: String,
    credential: Credential,
  )
  /// HTTP の口を持たない Service(queue・cron・Service からの呼び出しだけ)。
  Internal(service: String)
}

pub type Alias {
  /// Service の 2 本目の口。`external_id: True` は path の `:external_id` を店の外部 id として
  /// 引き直し、Args の `id` に入れる。
  Alias(
    name: String,
    service: String,
    method: Method,
    path: String,
    credential: Credential,
    external_id: Bool,
  )
  /// attached の口の 2 本目。
  AttachedAlias(
    name: String,
    attached: String,
    method: Method,
    path: String,
    credential: Credential,
    who: Who,
  )
}

pub type Attached {
  Attached(name: String, method: Method, path: String, who: Who)
}

pub type Job {
  /// 列挙の読み(`<service>/<query>` の SQL、穴は `$1` = 起動時刻)の行ごとに Service を 1 回ずつ呼ぶ。
  /// 行の `id` を Args の 1 つ目へ入れる。CAS に負けた行は飛ばして次へ。
  EachDue(service: String, query: String)
  /// hook が Args を作り、Service を 1 回呼ぶ(期間の計算など、宣言から導けない行)。
  Hooked(service: String, hook: String)
}

pub type Cron {
  /// `schedule` は wrangler の式。表に無い式で起きたときは outbox の sweep だけを回す。
  Cron(schedule: String, jobs: List(Job))
}

pub type DurableObject {
  /// `class` は wrangler の class 名、`module` は `src/` からの ★ の道(`user_do`)、`adapter` は
  /// その module が export する class、`methods` は DO の RPC として外へ出す method の名。
  DurableObject(
    class: String,
    module: String,
    adapter: String,
    methods: List(String),
  )
}

pub type Hook {
  /// `module` は `src/` からの ★ の道(`hooks`)、`name` はその module が export する関数の名。
  Hook(name: String, module: String)
}

/// connector の FFI の口(WGy r2、鷹野の裁定 2)。型と typed な包みは ★ に置き、
/// 生成物(`src/gen/connector/<name>.gleam`)は口だけを持つ ── 引数と戻りは型変数で、★ の包みが型を決める。
pub type Connector {
  Connector(name: String, ports: List(Port))
}

pub type Port {
  /// framework の operations の `call`(Read の境界)。`op` は operations の口の名
  Call(name: String, op: String)
  /// framework の operations の `call`(Write の境界)。通知のように応答を使わない口
  Send(name: String, op: String)
  /// framework の operations の `enqueue`(Write の境界)。`kind` は Queue の kind
  Enqueue(name: String, kind: String)
  /// ★ の JS の関数(`module` は `src/` からの道、拡張子無し)。ctx を先頭に取り Promise を返す(Read の境界)
  Fetch(name: String, module: String, js: String, arity: Int)
  /// ★ の JS の純関数
  Pure(name: String, module: String, js: String, arity: Int)
}

/// Entity の器と列の写像(WGy r3、鷹野の裁定)。`entity` は Entity の module 名(`muse_setting_spec`)、
/// `property` はレコードの欄の名(`type_`)。生成器は verb の SQL をこの写像で書き、穴の契約
/// (Property 1 つに穴 1 つ、値は codec の encode)は変えない ── 割る・写すのは SQL の側でする。
pub type Storage {
  /// Entity を Neon でなく Durable Object の SQLite に置く。`object` は `durable_objects` の class 名。
  /// 生成器はこの Entity の PG 向けの SQL(verb・読み)を出さず、器の ★ adapter が持つ
  InObject(entity: String, object: String)
  /// Property の列名を替える(`type_` → `type`、`default` → `default_value`)
  Column(entity: String, property: String, column: String)
  /// payload の無い構成子だけの sum を text 1 列で持つ。`values` は (構成子, 列の値)。
  /// 列名は Property 名(`Column` があればその列)
  Text(entity: String, property: String, values: List(#(String, String)))
  /// record(または `Option(record)`)の Property を複数の列に割る。`columns` は (record の欄, 列)
  Split(entity: String, property: String, columns: List(#(String, String)))
  /// `List(<値型>)` を PG の配列で持つ。`element` は要素の SQL の型(`uuid`)
  Array(entity: String, property: String, element: String)
}

/// 手書きの SQL(`db/queries/<service>/<query>.sql`、★)で引く読み(WGy r3)。生成器は
/// `gen/reads/<service>.gleam` の型付きの口(`<query>(<args>, then:)`)と runtime の振り分けを書き、
/// 行の写しは `hook`(`hooks` に宣言した ★ の関数)が持つ。型は Gleam の綴り(`List(course.Course)`)、
/// `imports` はその綴りが要る import の行の中身(`entity/course`)。引数が 2 つ以上なら口は組で渡す。
pub type ManualRead {
  ManualRead(
    service: String,
    query: String,
    args: List(#(String, String)),
    returns: String,
    imports: List(String),
    hook: String,
  )
}

/// root の形の上書き(WGy r3)。導出は「allow の Entity の key の型が Args に在れば、その Entity の行」。
/// 作る Service(Args の key は新しい行の鍵)や、主体の行を root にする Service はここに書く。
pub type RootShape {
  /// root に Entity の行を持たない(`Root(at, seed)`)
  Rootless(service: String)
  /// root を主体(session の subject)の行にする。Entity は allow の Entity
  OwnRoot(service: String)
  /// root を `entity`(module 名)の行にする。鍵は Args の `id`
  RootOf(service: String, entity: String)
  /// root に行の `version` 列(楽観ロックの版、Entity のレコードに無い列)を `version: Int` で載せる
  WithVersion(service: String)
  /// root に入口が運ぶ値を載せる(`browser` = 署名した browser cookie の id)。`type_` は Gleam の綴り、
  /// `import_` はその綴りが要る import の行の中身
  Carried(service: String, name: String, type_: String, import_: String)
}
