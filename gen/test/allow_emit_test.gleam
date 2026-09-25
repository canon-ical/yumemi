//// hw-2 ── `src/gen/allow/<m>` の生成と、root の Actor の別名。
//// article fixture の単位に、合成の Entity と Service を足して読む。

import glance
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import yumemi_gen
import yumemi_gen/emit/allow as allow_emit
import yumemi_gen/emit/root
import yumemi_gen/emit/types.{type File}
import yumemi_gen/reader
import yumemi_gen/reader/allow as allow_reader
import yumemi_gen/source
import yumemi_gen/stop

const fixture = "fixtures/article"

fn unit(path: String, text: String) -> source.Unit {
  let assert Ok(module) = glance.module(text)
  source.Unit(path: path, text: text, module: module)
}

const shop_entity = "import framework/party.{type PartyId}
import gen/types/slug.{type Slug}

pub type Shop {
  Shop(slug: Slug, party: PartyId)
}

pub type Phase {
  Open
  Closed
}

pub const edges: List(#(Phase, Phase)) = [#(Open, Closed)]

pub fn key(it: Shop) -> Slug {
  it.slug
}
"

const muse_entity = "import framework/party.{type PartyId}
import gen/types/slug.{type Slug}

pub type Muse {
  Muse(slug: Slug, party: PartyId)
}

pub type Phase {
  Draft
  Onboarded
}

pub const edges: List(#(Phase, Phase)) = [#(Draft, Onboarded)]

pub fn key(it: Muse) -> Slug {
  it.slug
}
"

const roster_entity = "import entity/shop.{type Shop}
import framework/er.{type Held}
import gen/types/slug.{type Slug}

pub type Roster {
  Roster(slug: Slug, shop: Held(Shop))
}

pub type Phase {
  Active
  Hidden
}

pub const edges: List(#(Phase, Phase)) = [#(Active, Hidden)]

pub fn key(it: Roster) -> Slug {
  it.slug
}
"

fn service(
  module: String,
  allow_module: String,
  clauses: String,
  body: String,
) {
  unit("service/" <> module, "import entity/muse
import entity/roster
import entity/shop
import framework/effect.{type Effect, Read}
import framework/step
import gen/allow/" <> allow_module <> " as allow
import gen/root/" <> module <> ".{type Root, type Service, Service}
import gen/types/slug.{type Slug}

pub const effect: Effect = Read

pub type Args {
  Args(slug: Slug)
}

pub const service: Service(Args, Bool, Nil) = Service(
  allow: [" <> clauses <> "],
  logic: logic,
)

pub fn logic(by, it: Root, _args: Args) {
" <> body <> "
}
")
}

fn clause(who: String, at: String, owner: String) -> String {
  "allow.Clause(who: allow."
  <> who
  <> ", at: allow."
  <> at
  <> ", owner: allow."
  <> owner
  <> "),"
}

fn base_units() -> List(source.Unit) {
  let assert Ok(units) = source.load(fixture)
  list.append(units, [
    unit("entity/shop", shop_entity),
    unit("entity/muse", muse_entity),
    unit("entity/roster", roster_entity),
  ])
}

fn generate(services: List(source.Unit)) -> #(List(File), List(stop.Note)) {
  let units = list.append(base_units(), services)
  let assert Ok(app) = reader.read(units)
  let usages = allow_reader.read(units)
  #(allow_emit.emit(app, usages, units), allow_emit.notes(app, usages))
}

fn file(files: List(File), path: String) -> String {
  let assert Ok(found) = list.find(files, fn(file) { file.path == path })
  found.text
}

fn shop_read() -> source.Unit {
  service(
    "shop_read",
    "shop",
    clause("Anyone", "AnyPhase", "NoOwner")
      <> clause("AsShop", "Only([shop.Open])", "Self")
      <> clause("Staff", "AnyPhase", "NoOwner"),
    "  // allow.party_of(by) はコメントなので数えない
  allow.is_self(by, it.shop) || allow.is_staff(by)",
  )
}

fn roster_read() -> source.Unit {
  service(
    "roster_read",
    "roster",
    clause("Anyone", "AnyPhase", "NoOwner")
      <> clause("AsShop", "AnyPhase", "ViaShopParty")
      <> clause("AsMuse", "Only([roster.Active])", "ViaMuseParty"),
    "  allow.is_self(by, it.roster)",
  )
}

// ── 正 ─────────────────────────────────────────────────────────────────────

pub fn allow_module_is_generated_for_every_root_allow_path_test() {
  let #(files, notes) = generate([shop_read(), roster_read()])
  let paths = list.map(files, fn(file) { file.path })
  list.contains(paths, "src/gen/allow/shop.gleam") |> should.be_true
  list.contains(paths, "src/gen/allow/roster.gleam") |> should.be_true
  // fixture の Service が指す allow も漏れなく出る
  list.contains(paths, "src/gen/allow/article.gleam") |> should.be_true
  notes |> should.equal([])
  let shop = file(files, "src/gen/allow/shop.gleam")
  string.starts_with(shop, "//// GENERATED from allow.shop [sha256:")
  |> should.be_true
}

pub fn who_owner_and_at_follow_the_clauses_test() {
  let #(files, _) = generate([shop_read(), roster_read()])
  let roster = file(files, "src/gen/allow/roster.gleam")
  string.contains(roster, "pub type Who {\n  Anyone\n  AsShop\n  AsMuse\n}")
  |> should.be_true
  // owner が複数 ── NoOwner は常に在り、句に書かれた Via が続く
  string.contains(
    roster,
    "pub type Owner {\n  NoOwner\n  ViaShopParty\n  ViaMuseParty\n}",
  )
  |> should.be_true
  string.contains(roster, "  Only(List(roster.Phase))") |> should.be_true
  string.contains(roster, "Clause(who: Who, at: At, owner: Owner)")
  |> should.be_true
  string.contains(
    roster,
    "pub type PartyActor {\n  PartyActor(party: PartyId)\n}",
  )
  |> should.be_true
  string.contains(roster, "pub type SystemActor {\n  SystemActor\n}")
  |> should.be_true
}

pub fn only_phase_comes_from_the_clause_module_test() {
  // allow module は roster だが、Only の要素は muse.Onboarded
  let found =
    service(
      "roster_claim",
      "roster",
      clause("AsMuse", "Only([muse.Onboarded])", "NoOwner"),
      "  True",
    )
  let #(files, notes) = generate([found])
  let roster = file(files, "src/gen/allow/roster.gleam")
  string.contains(roster, "  Only(List(muse.Phase))") |> should.be_true
  string.contains(roster, "roster.Phase") |> should.be_false
  string.contains(roster, "import entity/muse") |> should.be_true
  notes |> should.equal([])
}

pub fn sum_root_aliases_the_allow_actor_test() {
  let #(files, _) = generate([shop_read()])
  let shop = file(files, "src/gen/allow/shop.gleam")
  string.contains(
    shop,
    "pub type Actor {\n  ShopActor(shop.Shop)\n  StaffActor(staff.Staff)\n  AnyActor\n}",
  )
  |> should.be_true
  string.contains(shop, "pub type AnyActor =\n  Actor") |> should.be_true
  // root は独自の variant を出さない
  let units = list.append(base_units(), [shop_read()])
  let assert Ok(app) = reader.read(units)
  let assert Ok(read) =
    list.find(app.services, fn(service) { service.module == "shop_read" })
  root.actor_is_sum(read.subjects) |> should.be_true
  root.allow_path(read) |> should.equal("gen/allow/shop")
}

pub fn generated_root_text_uses_allow_actor_alias_test() {
  let assert Ok(#(generated, _)) = yumemi_gen.generate(fixture)
  let assert Ok(read) =
    list.find(generated, fn(file) {
      file.path == "src/gen/root/article_read.gleam"
    })
  string.contains(read.text, "pub type Actor =\n  allow.Actor\n")
  |> should.be_true
  string.contains(read.text, "logic: fn(Actor, Root, args)") |> should.be_true
  string.contains(read.text, "import entity/staff") |> should.be_false
  // 単節は今のまま
  let assert Ok(publish) =
    list.find(generated, fn(file) {
      file.path == "src/gen/root/article_publish.gleam"
    })
  string.contains(publish.text, "logic: fn(staff.Staff, Root, args)")
  |> should.be_true
  string.contains(publish.text, "pub type Actor") |> should.be_false
  // root が指す allow が生成束に在る
  list.any(generated, fn(file) { file.path == "src/gen/allow/article.gleam" })
  |> should.be_true
}

pub fn party_in_a_sum_is_authenticated_actor_test() {
  let follow =
    service(
      "muse_follow",
      "muse",
      clause("Party", "Only([muse.Onboarded])", "Self")
        <> clause("AsMuse", "AnyPhase", "NoOwner"),
      "  allow.party_of(by)",
    )
  let #(files, notes) = generate([follow])
  let muse = file(files, "src/gen/allow/muse.gleam")
  string.contains(
    muse,
    "pub type Actor {\n  MuseActor(muse.Muse)\n  AuthenticatedActor(party: PartyId)\n  AnyActor\n}",
  )
  |> should.be_true
  string.contains(muse, "pub fn party_of(by: Actor) -> Option(PartyId) {")
  |> should.be_true
  string.contains(muse, "    MuseActor(value) -> Some(value.party)")
  |> should.be_true
  string.contains(muse, "    AuthenticatedActor(party) -> Some(party)")
  |> should.be_true
  string.contains(muse, "    AnyActor -> None") |> should.be_true
  string.contains(muse, "import gleam/option.{type Option, None, Some}")
  |> should.be_true
  notes |> should.equal([])
}

pub fn system_alone_is_direct_and_in_a_sum_is_system_caller_test() {
  let tick =
    service(
      "muse_tick",
      "muse",
      clause("System", "AnyPhase", "NoOwner"),
      "  True",
    )
  let #(files, _) = generate([tick])
  let muse = file(files, "src/gen/allow/muse.gleam")
  // System だけの root は allow.SystemActor を直に取るので、Actor の和に入らない
  string.contains(muse, "pub type Actor {\n  AnyActor\n}") |> should.be_true
  string.contains(muse, "  System\n}") |> should.be_true

  let mix =
    service(
      "muse_mix",
      "muse",
      clause("System", "AnyPhase", "NoOwner")
        <> clause("AsMuse", "AnyPhase", "NoOwner"),
      "  True",
    )
  let #(files, _) = generate([tick, mix])
  let muse = file(files, "src/gen/allow/muse.gleam")
  string.contains(
    muse,
    "pub type Actor {\n  MuseActor(muse.Muse)\n  SystemCaller\n  AnyActor\n}",
  )
  |> should.be_true
  string.contains(muse, "pub type Who {\n  AsMuse\n  System\n}")
  |> should.be_true
}

pub fn judgements_are_emitted_only_when_called_test() {
  let #(files, notes) = generate([shop_read(), roster_read()])
  let shop = file(files, "src/gen/allow/shop.gleam")
  string.contains(shop, "pub fn is_self(by: Actor, it: shop.Shop) -> Bool {")
  |> should.be_true
  string.contains(shop, "    ShopActor(value) -> value.slug == it.slug")
  |> should.be_true
  string.contains(shop, "pub fn is_staff(by: Actor) -> Bool {")
  |> should.be_true
  string.contains(shop, "    StaffActor(_) -> True") |> should.be_true
  // コメントの `allow.party_of(` は呼び出しでない
  string.contains(shop, "party_of") |> should.be_false

  // Held(Shop) を持つ Roster は、店の key と Held の key を比べる
  let roster = file(files, "src/gen/allow/roster.gleam")
  string.contains(
    roster,
    "pub fn is_self(by: Actor, it: roster.Roster) -> Bool {",
  )
  |> should.be_true
  string.contains(
    roster,
    "    ShopActor(value) -> er.to_string(er.of_held(it.shop)) == slug.to_string(value.slug)",
  )
  |> should.be_true
  string.contains(roster, "import framework/er") |> should.be_true
  string.contains(roster, "import gen/types/slug") |> should.be_true
  string.contains(roster, "is_staff") |> should.be_false
  notes |> should.equal([])
}

pub fn is_entity_without_the_variant_is_false_test() {
  let found =
    service(
      "roster_peek",
      "roster",
      clause("AsShop", "AnyPhase", "NoOwner")
        <> clause("AsMuse", "AnyPhase", "NoOwner"),
      "  allow.is_staff(by)",
    )
  let #(files, _) = generate([found])
  let roster = file(files, "src/gen/allow/roster.gleam")
  string.contains(roster, "pub fn is_staff(_by: Actor) -> Bool {\n  False\n}")
  |> should.be_true
}

pub fn allow_module_without_entity_test() {
  let add =
    service(
      "ledger_add",
      "ledger",
      clause("Party", "AnyPhase", "NoOwner")
        <> clause("Staff", "Only([muse.Onboarded])", "NoOwner"),
      "  True",
    )
  let #(files, notes) = generate([add])
  let ledger = file(files, "src/gen/allow/ledger.gleam")
  string.starts_with(ledger, "//// GENERATED from allow.ledger [sha256:")
  |> should.be_true
  string.contains(ledger, "pub type Who {\n  Party\n  Staff\n}")
  |> should.be_true
  string.contains(ledger, "  Only(List(muse.Phase))") |> should.be_true
  string.contains(
    ledger,
    "pub type Actor {\n  StaffActor(staff.Staff)\n  AuthenticatedActor(party: PartyId)\n  AnyActor\n}",
  )
  |> should.be_true
  notes |> should.equal([])

  // Entity でも phase でもない allow module は AnyPhase だけ
  let plain =
    service(
      "ledger_list",
      "ledger",
      clause("Party", "AnyPhase", "NoOwner"),
      "  True",
    )
  let #(files, _) = generate([plain])
  let ledger = file(files, "src/gen/allow/ledger.gleam")
  string.contains(ledger, "pub type At {\n  AnyPhase\n}") |> should.be_true
}

pub fn shorthand_lowercase_clause_becomes_a_constant_test() {
  let #(files, _) = generate([])
  let article = file(files, "src/gen/allow/article.gleam")
  string.contains(
    article,
    "pub const staff: Clause = Clause(who: Staff, at: AnyPhase, owner: NoOwner)",
  )
  |> should.be_true
  string.contains(article, "  Only(List(article.Phase))") |> should.be_true
}

pub fn input_hash_follows_the_services_of_the_module_test() {
  let #(one, _) = generate([shop_read(), roster_read()])
  let #(two, _) = generate([shop_read(), roster_read()])
  one |> should.equal(two)
  let changed =
    service(
      "roster_read",
      "roster",
      clause("Anyone", "AnyPhase", "NoOwner"),
      "  allow.is_self(by, it.roster)",
    )
  let #(three, _) = generate([shop_read(), changed])
  let header = fn(files, path) {
    let assert Ok(line) = list.first(string.split(file(files, path), "\n"))
    line
  }
  header(one, "src/gen/allow/roster.gleam")
  |> should.not_equal(header(three, "src/gen/allow/roster.gleam"))
  header(one, "src/gen/allow/shop.gleam")
  |> should.equal(header(three, "src/gen/allow/shop.gleam"))
}

pub fn owner_party_rule_test() {
  allow_reader.owner_entity("ViaMuseParty") |> should.equal(Some("Muse"))
  allow_reader.owner_entity("ViaShopParty") |> should.equal(Some("Shop"))
  allow_reader.owner_entity("Self") |> should.equal(None)
  allow_reader.owner_entity("NoOwner") |> should.equal(None)
  allow_reader.owner_entity("ViaParty") |> should.equal(None)
}

// ── 負 ─────────────────────────────────────────────────────────────────────

pub fn owner_without_entity_or_party_is_exit_four_test() {
  let found =
    service(
      "roster_bad",
      "roster",
      clause("AsShop", "AnyPhase", "ViaGhostParty")
        <> clause("AsShop", "AnyPhase", "ViaTagParty"),
      "  True",
    )
  let #(_, notes) = generate([found])
  notes
  |> list.any(fn(note) {
    note.class == stop.Conflict
    && string.contains(note.text, "allow.roster")
    && string.contains(note.text, "ViaGhostParty")
    && string.contains(note.text, "Entity Ghost が無い")
  })
  |> should.be_true
  notes
  |> list.any(fn(note) {
    note.class == stop.Conflict
    && string.contains(note.text, "ViaTagParty")
    && string.contains(note.text, "party 欄が無い")
  })
  |> should.be_true
  stop.worst(notes) |> should.equal(4)
}

pub fn unknown_owner_is_vocabulary_test() {
  let found =
    service(
      "roster_odd",
      "roster",
      clause("AsShop", "AnyPhase", "Somebody"),
      "  True",
    )
  let #(_, notes) = generate([found])
  notes
  |> list.any(fn(note) {
    note.class == stop.Vocabulary && string.contains(note.text, "Somebody")
  })
  |> should.be_true
}

pub fn only_across_two_entities_is_exit_four_test() {
  let found =
    service(
      "roster_split",
      "roster",
      clause("AsShop", "Only([shop.Open])", "NoOwner")
        <> clause("AsMuse", "Only([muse.Onboarded])", "NoOwner"),
      "  True",
    )
  let #(_, notes) = generate([found])
  notes
  |> list.any(fn(note) {
    note.class == stop.Conflict
    && string.contains(note.text, "Only の phase が複数の Entity に跨る: shop, muse")
  })
  |> should.be_true
  // 同じ Entity の phase を並べるのは 1 つと数える
  let same =
    service(
      "roster_same",
      "roster",
      clause("AsShop", "Only([roster.Active, roster.Hidden])", "NoOwner"),
      "  True",
    )
  let #(_, notes) = generate([same])
  notes |> should.equal([])
}

pub fn is_self_without_entity_is_not_implemented_test() {
  let found =
    service(
      "ledger_check",
      "ledger",
      clause("Staff", "AnyPhase", "NoOwner")
        <> clause("Anyone", "AnyPhase", "NoOwner"),
      "  allow.is_self(by, it)",
    )
  let #(files, notes) = generate([found])
  notes
  |> list.any(fn(note) {
    note.class == stop.NotImplemented
    && string.contains(note.text, "allow.ledger: is_self")
  })
  |> should.be_true
  string.contains(file(files, "src/gen/allow/ledger.gleam"), "is_self")
  |> should.be_false
}

pub fn fixture_notes_are_unchanged_by_allow_test() {
  // 既存の fixture に allow の注記は出ない
  let assert Ok(#(_, notes)) = yumemi_gen.generate(fixture)
  notes
  |> list.any(fn(note) { string.starts_with(note.text, "allow.") })
  |> should.be_false
}
