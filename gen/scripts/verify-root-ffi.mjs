#!/usr/bin/env node
//// root 相対の矢印 read(P0-5)の検算。柏木ゲート 2(3 回目)の再現 `root-real.mjs` と同じ経路で書く:
////
////   生成 `gen/reads/<service>.gleam` をコンパイル → musearch の実 `decodeArticle` / `decodeWidget` で root を作る
////   → musearch の実 `makeContext` に渡す → `step.interpret` → 継続関数が受け取った値を見る
////
//// 関係先の取得と復号は framework の Context 契約 `relation(relation, keys)`。
////   (a) 実 makeContext から契約を一時的に外すと framework が名指しで落とし、Held(key だけ)を Entity として渡さないこと
////   (b) 実 makeContext の契約を生成 SQL + 実 codec の検証関数へ差し替えると、
////       Held / Option(Held) / Link / Multi の 3 形が出力型どおりの Entity 値で継続関数に届くこと
//// の両方を、実 PG 上の生成 SQL(`gen/sql/queries/<service>/to_<prop>.sql`)で検査する。
//// 検証側が resolve() を自作して経路を外すことはしない ── 検証側が足すのは契約の相手側(SQL 実行 + 復号)だけ。
////
////   PGHOST=127.0.0.1 PGPORT=55432 PGUSER=yumemism PGDATABASE=postgres \
////   node gen/scripts/verify-root-ffi.mjs <musearch-out> <relation-out> <work-dir>
////
//// 3 形のうち Multi は musearch に無い(er.Multi は gen-3b で framework に足した)ので、fixtures/relation
//// (photo_read: Held / Link / Multi)を同じ経路で通す。fixture には runtime が無いので、その復号関数だけは
//// この検証が持つ(musearch 側は実 codec)。

import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";
import pg from "/home/yumemism/yumemism_repo/musearch/app/node_modules/pg/lib/index.js";

const [, , musearchOut, relationOut, workDir] = process.argv;
if (!musearchOut || !relationOut || !workDir) {
  console.error(
    "usage: verify-root-ffi.mjs <musearch-out> <relation-out> <work-dir>",
  );
  process.exit(2);
}

const here = path.dirname(new URL(import.meta.url).pathname);
const repoRoot = path.resolve(here, "../..");
const genDir = path.resolve(here, "..");
const musearchApp =
  process.env.MUSEARCH_APP || "/home/yumemism/yumemism_repo/musearch/app";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function equal(actual, expected, label) {
  if (actual !== expected) {
    throw new Error(
      `${label}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

function readSqlMap(out) {
  const map = {};
  const base = path.join(out, "gen/sql/queries");
  for (const service of fs.readdirSync(base)) {
    const dir = path.join(base, service);
    if (!fs.statSync(dir).isDirectory()) continue;
    for (const file of fs.readdirSync(dir)) {
      if (!file.endsWith(".sql")) continue;
      map[`${service}/${file.slice(0, -4)}`] = fs.readFileSync(
        path.join(dir, file),
        "utf8",
      );
    }
  }
  return map;
}

// ── harness ────────────────────────────────────────────────────────────────

function writeToml(dir, name) {
  fs.writeFileSync(
    path.join(dir, "gleam.toml"),
    `name = "${name}"\nversion = "0.1.0"\ntarget = "javascript"\n[dependencies]\ngleam_stdlib = ">= 0.44.0 and < 2.0.0"\nyumemi = { path = "${repoRoot}" }\n`,
  );
}

function copyInto(source, destination) {
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.copyFileSync(source, destination);
}

function gleamBuild(dir) {
  const result = spawnSync("gleam", ["build", "--target", "javascript"], {
    cwd: dir,
    encoding: "utf8",
  });
  if (result.status !== 0) {
    throw new Error(`gleam build failed in ${dir}\n${result.stdout}\n${result.stderr}`);
  }
}

/// musearch の harness:実 ★(types / entity)と実 allow に、生成 root / reads を足した package。
/// コンパイル後に musearch の実 build(codec.mjs / runtime.mjs を含む)を同じ build root へ写し、
/// prelude / gleam_stdlib を 1 つにする(別 build の Option / List は instanceof で別物になるため)。
function buildMusearchHarness(dir) {
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
  writeToml(dir, "gate_root");
  copyInto(path.join(musearchApp, "src/types.gleam"), path.join(dir, "src/types.gleam"));
  for (const entity of ["muse", "article", "free_space", "muse_heaven", "widget"]) {
    copyInto(
      path.join(musearchApp, `src/entity/${entity}.gleam`),
      path.join(dir, `src/entity/${entity}.gleam`),
    );
  }
  for (const file of fs.readdirSync(path.join(musearchApp, "src/gen/types"))) {
    copyInto(
      path.join(musearchApp, "src/gen/types", file),
      path.join(dir, "src/gen/types", file),
    );
  }
  // yumemi-1 keeps the FFI beside `src/text.gleam`; the old gen/ location
  // belonged to the pre-Hex app layout.
  copyInto(path.join(musearchApp, "src/text_ffi.mjs"), path.join(dir, "src/text_ffi.mjs"));
  for (const allow of ["article", "widget"]) {
    copyInto(
      path.join(musearchApp, `src/gen/allow/${allow}.gleam`),
      path.join(dir, `src/gen/allow/${allow}.gleam`),
    );
  }
  for (const service of ["article_read", "widget_edit"]) {
    copyInto(
      path.join(musearchOut, `src/gen/root/${service}.gleam`),
      path.join(dir, `src/gen/root/${service}.gleam`),
    );
    copyInto(
      path.join(musearchOut, `src/gen/reads/${service}.gleam`),
      path.join(dir, `src/gen/reads/${service}.gleam`),
    );
  }
  gleamBuild(dir);
  const built = path.join(dir, "build/dev/javascript");
  // yumemi-1 resolves the framework from Hex as `yumemi`; the old local
  // package name was `musearch_framework`.
  for (const pkg of ["yumemi", "musearch_app"]) {
    fs.cpSync(path.join(musearchApp, "build/dev/javascript", pkg), path.join(built, pkg), {
      recursive: true,
    });
  }
  // 写した codec / runtime が musearch の実 build と同じものであることを確かめる(検証の相手を替えていない)。
  for (const file of ["gen/codec.mjs", "gen/runtime.mjs"]) {
    const real = fs.readFileSync(path.join(musearchApp, "build/dev/javascript/musearch_app", file));
    const copy = fs.readFileSync(path.join(built, "musearch_app", file));
    assert(real.equals(copy), `${file} in the harness differs from musearch's build`);
    const source = fs.readFileSync(path.join(musearchApp, "src", file));
    assert(real.equals(source), `${file} in musearch's build differs from its source`);
  }
  return built;
}

/// fixture の harness:fixtures/relation の ★ に生成 allow / root / reads を足した package。
function buildRelationHarness(dir) {
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
  writeToml(dir, "gate_relation");
  const fixture = path.join(genDir, "fixtures/relation/src");
  copyInto(path.join(fixture, "types.gleam"), path.join(dir, "src/types.gleam"));
  for (const entity of ["album", "shelf", "label", "photo"]) {
    copyInto(path.join(fixture, `entity/${entity}.gleam`), path.join(dir, `src/entity/${entity}.gleam`));
  }
  for (const file of fs.readdirSync(path.join(relationOut, "src/gen/types"))) {
    copyInto(path.join(relationOut, "src/gen/types", file), path.join(dir, "src/gen/types", file));
  }
  // fixture には allow module が無い(root は allow module の Entity で決まる)── 最小の allow を置く。
  fs.mkdirSync(path.join(dir, "src/gen/allow"), { recursive: true });
  fs.writeFileSync(
    path.join(dir, "src/gen/allow/photo.gleam"),
    "pub type Who {\n  Anyone\n}\n\npub type At {\n  AnyPhase\n}\n\npub type Owner {\n  NoOwner\n}\n\npub type Clause {\n  Clause(who: Who, at: At, owner: Owner)\n}\n",
  );
  copyInto(path.join(relationOut, "src/gen/root/photo_read.gleam"), path.join(dir, "src/gen/root/photo_read.gleam"));
  copyInto(path.join(relationOut, "src/gen/reads/photo_read.gleam"), path.join(dir, "src/gen/reads/photo_read.gleam"));
  gleamBuild(dir);
  return path.join(dir, "build/dev/javascript");
}

// ── storage boundary ──────────────────────────────────────────────────────

const client = new pg.Client({
  host: process.env.PGHOST || "127.0.0.1",
  port: Number(process.env.PGPORT || 55432),
  user: process.env.PGUSER || "yumemism",
  database: process.env.PGDATABASE || "postgres",
});
await client.connect();

/// musearch の driver と同じ形(`query(text, params, key)`)。呼び出しを記録する。
function storage(schema, log) {
  return {
    async query(text, params, key) {
      log.push({ key, params });
      const result = await client.query(text.replaceAll("app.", `${schema}.`), params);
      return result.rows;
    },
    async transaction() {
      throw new Error("unexpected transaction");
    },
  };
}

/// Context 契約の runtime 側:宣言の名前で生成 SQL を引き、鍵の列を jsonb で渡し、宣言の target の復号関数で復号する。
/// (musearch の生成 runtime が持つべき 1 関数。名前推測は無い ── `relation` の欄をそのまま使う。)
function relationCapability(db, sqlMap, decoders) {
  return async (relation, keys) => {
    const sql = sqlMap[`${relation.service}/${relation.query}`];
    if (!sql) throw new Error(`generated SQL is missing: ${relation.service}/${relation.query}`);
    const decode = decoders[relation.target];
    if (!decode) throw new Error(`decoder is missing for target ${relation.target}`);
    const rows = await db.query(sql, [JSON.stringify(keys)], `${relation.service}/${relation.query}`);
    return rows.map(decode);
  };
}

const UUID = (n) => `00000000-0000-0000-0000-${String(n).padStart(12, "0")}`;

let passed = 0;
function pass(label) {
  passed++;
  console.log(`PASS ${label}`);
}

async function expectRejected(promise, label) {
  try {
    await promise;
  } catch (error) {
    return error;
  }
  throw new Error(`${label}: expected a rejection`);
}

try {
  // ── musearch:実 codec + 実 makeContext ──────────────────────────────────
  const built = buildMusearchHarness(path.join(workDir, "musearch-harness"));
  const load = (relative) => import(pathToFileURL(path.join(built, relative)).href);
  const codec = await load("musearch_app/gen/codec.mjs");
  const { makeContext } = await load("musearch_app/gen/runtime.mjs");
  const { Muse } = await load("musearch_app/entity/muse.mjs");
  const { FreeSpace } = await load("musearch_app/entity/free_space.mjs");
  const { MuseHeaven } = await load("musearch_app/entity/muse_heaven.mjs");
  const { Some, None } = await load("gleam_stdlib/gleam/option.mjs");
  const step = await load("yumemi/framework/step.mjs");
  const articleRead = await load("gate_root/gen/reads/article_read.mjs");
  const articleRoot = await load("gate_root/gen/root/article_read.mjs");
  const widgetEdit = await load("gate_root/gen/reads/widget_edit.mjs");
  const widgetRoot = await load("gate_root/gen/root/widget_edit.mjs");
  const musearchSql = readSqlMap(musearchOut);
  const capture = () => {
    const box = { received: undefined, called: 0 };
    box.then = (value) => {
      box.received = value;
      box.called++;
      return step.fail("captured");
    };
    return box;
  };

  const schema = "gate3b_root";
  await client.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);
  await client.query(`CREATE SCHEMA ${schema}`);
  await client.query(`
    CREATE TABLE ${schema}.muse(id uuid PRIMARY KEY,party text NOT NULL,handle text NOT NULL,name text NOT NULL,
      headline text,icon text,theme jsonb,age_verified boolean NOT NULL);
    CREATE TABLE ${schema}.free_space(id uuid PRIMARY KEY,muse_id uuid NOT NULL,title text NOT NULL,
      "order" integer NOT NULL,visible boolean NOT NULL);
    CREATE TABLE ${schema}.muse_heaven(id uuid PRIMARY KEY,muse_id uuid NOT NULL,shop_id text NOT NULL,
      girl_id text NOT NULL,shop_name text NOT NULL,page_url text NOT NULL);
    INSERT INTO ${schema}.muse VALUES('${UUID(2)}','party-2','hana','Hana','hello',NULL,NULL,true);
    INSERT INTO ${schema}.free_space VALUES('${UUID(3)}','${UUID(2)}','Space 3',0,true);
    INSERT INTO ${schema}.muse_heaven VALUES('${UUID(4)}','${UUID(2)}','1234','5678','Shop 4','https://example.com/4');
  `);
  const decoders = {
    muse: codec.decodeMuse,
    free_space: codec.decodeFreeSpace,
    muse_heaven: codec.decodeMuseHeaven,
  };

  const article = codec.decodeArticle({
    id: UUID(1), muse_id: UUID(2), title: "title", body: "body", images: [], version: 7,
    slot: null, posted_on: null, publish_at: null,
  });
  const aRoot = new articleRoot.Root(article, null, null, "gate3b");

  // (a) 柏木の再現そのもの:契約の無い実 makeContext。framework は名指しで落とし、Held を渡さない。
  {
    const log = [];
    const context = makeContext({
      record: { name: "article_read" },
      db: { query() { log.push("query"); throw new Error("unexpected query"); } },
      root: aRoot, at: "2026-09-20T00:00:00Z", seed: "gate3b",
    });
    // The current yumemi-1 runtime provides its storage capability by
    // default. Remove only that capability here to exercise the framework's
    // missing-contract rejection against the real makeContext object.
    delete context.relation;
    const box = capture();
    const error = await expectRejected(
      step.interpret(articleRead.to_muse(aRoot, box.then), context),
      "article_read.to_muse without relation()",
    );
    equal(error.code, "relation_contract", `error code: ${error.message}`);
    assert(error.message.includes("Context does not implement relation(relation, keys)"), error.message);
    assert(error.message.includes("article_read/ArticleToMuse (article.muse -> muse)"), error.message);
    equal(box.called, 0, "continuation calls");
    equal(box.received, undefined, "continuation value");
    equal(log.length, 0, "db calls");
    pass("P0-5 (a) real makeContext without relation(): rejected by name, continuation never receives Held");
  }

  // (b) 契約の runtime 側を足した実 makeContext:Held -> Muse(実 decodeMuse)。
  {
    const log = [];
    const db = storage(schema, log);
    const context = makeContext({ record: { name: "article_read" }, db, root: aRoot, at: "2026-09-20T00:00:00Z", seed: "gate3b" });
    context.relation = relationCapability(db, musearchSql, decoders);
    const box = capture();
    const outcome = await step.interpret(articleRead.to_muse(aRoot, box.then), context);
    equal(outcome.constructor.name, "Fail", "outcome");
    equal(box.called, 1, "continuation calls");
    assert(box.received instanceof Muse, `expected Muse, got ${box.received?.constructor?.name}`);
    assert(box.received !== article.muse, "continuation received the Held itself");
    equal(codec.text(box.received.id), UUID(2), "muse.id");
    equal(codec.text(box.received.handle), "hana", "muse.handle");
    equal(codec.text(box.received.name), "Hana", "muse.name");
    equal(codec.text(codec.unwrap(box.received.headline)), "hello", "muse.headline");
    equal(box.received.age_verified, true, "muse.age_verified");
    equal(log.length, 1, "db calls");
    equal(log[0].key, "article_read/to_muse", "sql key");
    equal(log[0].params[0], JSON.stringify([UUID(2)]), "sql params");
    pass("P0-5 (b) Held(Muse) -> real decodeMuse -> Muse reaches fn(Muse) through generated SQL on PG");
  }

  // (c) 関係先が無い Held(FK の破れ)は契約違反として落ち、継続関数は呼ばれない。
  {
    const missing = codec.decodeArticle({
      id: UUID(1), muse_id: UUID(9), title: "t", body: "b", images: [], version: 1, slot: null, posted_on: null, publish_at: null,
    });
    const root = new articleRoot.Root(missing, null, null, "gate3b");
    const log = [];
    const db = storage(schema, log);
    const context = makeContext({ record: { name: "article_read" }, db, root, at: "2026-09-20T00:00:00Z", seed: "gate3b" });
    context.relation = relationCapability(db, musearchSql, decoders);
    const box = capture();
    const error = await expectRejected(step.interpret(articleRead.to_muse(root, box.then), context), "missing target");
    equal(error.code, "relation_contract", "error code");
    assert(error.message.includes("expected 1 target row(s), found 0"), error.message);
    equal(box.called, 0, "continuation calls");
    equal(log.length, 1, "db calls");
    pass("P0-5 (c) Held whose row is missing: rejected as relation_contract, continuation not called");
  }

  // (d) Option(Held) の 2 形:Some は復号された Entity、None は読まずに None。実 decodeWidget。
  const widgetRow = (space, heaven) => ({
    id: UUID(5), muse_id: UUID(2), space_id: space, kind: "text", order: 0, visible: true,
    title: null, body: null, image: null, caption: null, url: null, heaven_id: heaven,
    design: null, num: null, color: null, fontsize: null, height: null,
  });
  {
    const widget = codec.decodeWidget(widgetRow(UUID(3), UUID(4)));
    assert(widget.space instanceof Some, "fixture: widget.space is Some");
    const root = new widgetRoot.Root(widget, null, "gate3b");
    const log = [];
    const db = storage(schema, log);
    const context = makeContext({ record: { name: "widget_edit" }, db, root, at: "2026-09-20T00:00:00Z", seed: "gate3b" });
    context.relation = relationCapability(db, musearchSql, decoders);

    const muse = capture();
    await step.interpret(widgetEdit.to_muse(root, muse.then), context);
    assert(muse.received instanceof Muse, "to_muse -> Muse");
    equal(codec.text(muse.received.handle), "hana", "widget.to_muse handle");

    const space = capture();
    await step.interpret(widgetEdit.to_space(root, space.then), context);
    assert(space.received instanceof Some, `to_space -> Some, got ${space.received?.constructor?.name}`);
    assert(space.received[0] instanceof FreeSpace, "to_space -> Some(FreeSpace)");
    equal(codec.text(space.received[0].title), "Space 3", "space.title");
    equal(codec.text(space.received[0].id), UUID(3), "space.id");

    const heaven = capture();
    await step.interpret(widgetEdit.to_heaven(root, heaven.then), context);
    assert(heaven.received instanceof Some && heaven.received[0] instanceof MuseHeaven, "to_heaven -> Some(MuseHeaven)");
    equal(codec.text(heaven.received[0].shop_name), "Shop 4", "heaven.shop_name");
    equal(log.map((entry) => entry.key).join(","), "widget_edit/to_muse,widget_edit/to_space,widget_edit/to_heaven", "sql keys");
    pass("P0-5 (d) Option(Held) Some: to_space -> Some(FreeSpace), to_heaven -> Some(MuseHeaven) via real decoders");
  }
  {
    const widget = codec.decodeWidget(widgetRow(null, null));
    assert(widget.space instanceof None, "fixture: widget.space is None");
    const root = new widgetRoot.Root(widget, null, "gate3b");
    const log = [];
    const db = storage(schema, log);
    const context = makeContext({ record: { name: "widget_edit" }, db, root, at: "2026-09-20T00:00:00Z", seed: "gate3b" });
    context.relation = relationCapability(db, musearchSql, decoders);
    const space = capture();
    await step.interpret(widgetEdit.to_space(root, space.then), context);
    assert(space.received instanceof None, `to_space -> None, got ${space.received?.constructor?.name}`);
    const heaven = capture();
    await step.interpret(widgetEdit.to_heaven(root, heaven.then), context);
    assert(heaven.received instanceof None, "to_heaven -> None");
    equal(log.length, 0, "db calls for None");
    pass("P0-5 (e) Option(Held) None: to_space / to_heaven -> None without a query");
  }

  // ── fixture:Held / Link / Multi の 3 形(復号関数はこの検証が持つ ── fixture に runtime は無い)──
  const relationBuilt = buildRelationHarness(path.join(workDir, "relation-harness"));
  const loadR = (relative) => import(pathToFileURL(path.join(relationBuilt, relative)).href);
  const er = await loadR("yumemi/framework/er.mjs");
  const stepR = await loadR("yumemi/framework/step.mjs");
  const optionR = await loadR("gleam_stdlib/gleam/option.mjs");
  const prelude = await loadR("prelude.mjs");
  const album = await loadR("gate_relation/entity/album.mjs");
  const shelf = await loadR("gate_relation/entity/shelf.mjs");
  const label = await loadR("gate_relation/entity/label.mjs");
  const photo = await loadR("gate_relation/entity/photo.mjs");
  const photoRead = await loadR("gate_relation/gen/reads/photo_read.mjs");
  const photoRoot = await loadR("gate_relation/gen/root/photo_read.mjs");
  const types = {};
  for (const name of ["album_id", "album_title", "shelf_id", "shelf_name", "label_id", "label_name", "photo_id", "photo_caption", "photo_order"]) {
    types[name] = await loadR(`gate_relation/gen/types/${name}.mjs`);
  }
  const parsed = (name, raw) => {
    const result = types[name].parse(raw);
    if (!result.isOk()) throw new Error(`invalid ${name}: ${raw}`);
    return result[0];
  };
  const relationSql = readSqlMap(relationOut);
  const fixtureDecoders = {
    album: (r) => new album.Album(parsed("album_id", r.id), parsed("album_title", r.title)),
    shelf: (r) => new shelf.Shelf(parsed("shelf_id", r.id), parsed("shelf_name", r.name)),
    label: (r) => new label.Label(parsed("label_id", r.id), parsed("label_name", r.name)),
  };
  const fixtureSchema = "gate3b_relation";
  await client.query(`DROP SCHEMA IF EXISTS ${fixtureSchema} CASCADE`);
  await client.query(`CREATE SCHEMA ${fixtureSchema}`);
  await client.query(`
    CREATE TABLE ${fixtureSchema}.album(id uuid PRIMARY KEY,title text NOT NULL);
    CREATE TABLE ${fixtureSchema}.shelf(id uuid PRIMARY KEY,name text NOT NULL);
    CREATE TABLE ${fixtureSchema}.label(id uuid PRIMARY KEY,name text NOT NULL);
    INSERT INTO ${fixtureSchema}.album VALUES('${UUID(11)}','Album 11');
    INSERT INTO ${fixtureSchema}.shelf VALUES('${UUID(12)}','Shelf 12');
    INSERT INTO ${fixtureSchema}.label VALUES('${UUID(21)}','L21'),('${UUID(22)}','L22'),('${UUID(23)}','L23');
  `);
  const captureR = () => {
    const box = { received: undefined, called: 0 };
    box.then = (value) => { box.received = value; box.called++; return stepR.fail("captured"); };
    return box;
  };
  const makePhoto = (shelfKey, labelKeys) =>
    new photo.Photo(
      parsed("photo_id", UUID(10)),
      er.held_from_row({ key: UUID(11) }),
      shelfKey ? new optionR.Some(er.key(shelfKey)) : new optionR.None(),
      er.multi_from_rows(prelude.toList(labelKeys.map((key) => ({ key })))),
      parsed("photo_caption", "c"),
      parsed("photo_order", 1),
    );
  /// fixture には musearch の makeContext が無いので、Context は契約の最小形(relation だけ)。
  const fixtureContext = (log) => {
    const db = storage(fixtureSchema, log);
    return { relation: relationCapability(db, relationSql, fixtureDecoders) };
  };
  {
    const root = new photoRoot.Root(makePhoto(UUID(12), [UUID(22), UUID(21), UUID(23)]), null, "gate3b");
    const log = [];
    const context = fixtureContext(log);
    const a = captureR();
    await stepR.interpret(photoRead.to_album(root, a.then), context);
    assert(a.received instanceof album.Album, "to_album -> Album");
    equal(a.received.title.value, "Album 11", "album.title");
    const s = captureR();
    await stepR.interpret(photoRead.to_shelf(root, s.then), context);
    assert(s.received instanceof optionR.Some && s.received[0] instanceof shelf.Shelf, "to_shelf (Link) -> Some(Shelf)");
    equal(s.received[0].name.value, "Shelf 12", "shelf.name");
    const l = captureR();
    await stepR.interpret(photoRead.to_labels(root, l.then), context);
    const labels = [...l.received];
    equal(labels.length, 3, "to_labels (Multi) length");
    assert(labels.every((item) => item instanceof label.Label), "to_labels -> List(Label)");
    equal(labels.map((item) => item.name.value).join(","), "L22,L21,L23", "to_labels keeps key order");
    equal(log.map((entry) => entry.key).join(","), "photo_read/to_album,photo_read/to_shelf,photo_read/to_labels", "sql keys");
    equal(log[2].params[0], JSON.stringify([UUID(22), UUID(21), UUID(23)]), "to_labels params");
    pass("P0-5 (f) fixture: Held -> Album, Link -> Some(Shelf), Multi -> List(Label) in key order");
  }
  {
    const root = new photoRoot.Root(makePhoto(null, []), null, "gate3b");
    const log = [];
    const context = fixtureContext(log);
    const s = captureR();
    await stepR.interpret(photoRead.to_shelf(root, s.then), context);
    assert(s.received instanceof optionR.None, "to_shelf (Link None) -> None");
    const l = captureR();
    await stepR.interpret(photoRead.to_labels(root, l.then), context);
    equal([...l.received].length, 0, "to_labels (empty Multi) -> []");
    equal(log.length, 0, "db calls for None / empty");
    pass("P0-5 (g) fixture: Link None -> None, empty Multi -> [] without a query");
  }
  {
    const root = new photoRoot.Root(makePhoto(null, [UUID(22), UUID(99)]), null, "gate3b");
    const log = [];
    const context = fixtureContext(log);
    const l = captureR();
    const error = await expectRejected(stepR.interpret(photoRead.to_labels(root, l.then), context), "partial Multi");
    equal(error.code, "relation_contract", "error code");
    assert(error.message.includes("expected 2 target row(s), found 1"), error.message);
    equal(l.called, 0, "continuation calls");
    pass("P0-5 (h) fixture: Multi with a missing key is rejected, continuation not called");
  }

  console.log(`verify-root-ffi: ${passed} checks PASS`);
} finally {
  await client.query("DROP SCHEMA IF EXISTS gate3b_root CASCADE");
  await client.query("DROP SCHEMA IF EXISTS gate3b_relation CASCADE");
  await client.end();
}
