// 0.12 段 C(Y3)── runtime(interactive.mjs)の Args の送り方を、表の型(wire)ごとに 1 行 1 件で見る。
import { internals } from "./yumemi/front/interactive.mjs";

export function runtime_wire() {
  const out = [];
  const check = (name, ok) => out.push((ok ? "ok " : "NG ") + name);
  const w = internals.wireValue;
  const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
  check("bool true", w("bool", "on") === true && w("bool", "true") === true);
  check("bool false", w("bool", "") === false && w("bool", "False") === false);
  check("bool unreadable stays text", w("bool", "maybe") === "maybe");
  check("int", w("int", "42") === 42 && w("int", "4.2") === "4.2");
  check("float", w("float", "2.5") === 2.5 && w("float", "3") === 3);
  check("option empty is null", w({ option: "int" }, "") === null && w({ option: "int" }, "7") === 7);
  check("list of json strings", same(w({ list: "int" }, '["1","2"]'), [1, 2]));
  check("list of controls", same(w({ list: "text" }, ["a", "b"]), ["a", "b"]));
  check("option list", w({ option: { list: "bool" } }, "") === null);
  check("json body", same(w("json", '{"a":1}'), { a: 1 }) && w("json", "{bad") === "{bad");
  check("path holes are encoded", internals.fillPath("/api/a/:slug/x", { slug: "a b/c" }) === "/api/a/a%20b%2Fc/x");
  check("text", w("text", "x") === "x");
  return out.join("\n");
}
