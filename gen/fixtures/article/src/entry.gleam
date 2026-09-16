// ★ src/entry.gleam ── 人が来る入口の群。アプリ = ER 1つ + 入口の群 + deploy 1つ(手順1)。
//// ここに書くのは「どの IdP に繋ぐか」「どの入口が、誰を、どの主体として受け入れ、
//// どの Service を開くか」だけ。sign in の画面も OIDC の往復も session の置き場も
//// callback の URL も全部 framework 側で、src/gen/entry/ が吐く(第7巡)。
//// scheduled と queue の Entrypoint はここに書かない ── allow が System の Service の
//// 有無から生成器が導く(人が来ない入口なので「開く」判断が無い)。
import entity/staff.{type Staff}
import framework/entry.{type Entry, type Idp, All, AnyParty, Anonymous, Cli, Http, Idp, Mcp, NoSubject, ReadOnly}

/// どのアプリも IdP を1つ持つ(`has IdP`)。セルフホストで、これも framework 上の1アプリ。

pub const entries: List(Entry) = [
  // 公開サイト。名札を要求しないので主体も作らない。
  Http(name: "public", subject: NoSubject, admit: Anonymous, services: ReadOnly),
  // 管理画面。初ログインで Staff が自動作成される。手前に Access が居る前提。
  Http(name: "admin", subject: Staff, admit: AnyParty, services: All),
  Mcp(name: "admin", subject: Staff, admit: AnyParty, services: All),
  Cli(name: "ops", subject: Staff, admit: AnyParty, services: All),
]
