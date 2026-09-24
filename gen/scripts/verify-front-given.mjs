#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { prepareFrontScratch } from "./front-harness.mjs";

const work = prepareFrontScratch("given", "public");
const defaultShell = path.join(work, "src/gen/shell.mjs");
const shellPath = path.resolve(process.argv[2] ?? defaultShell);

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function loadAddGivenAttributes() {
  const source = fs.readFileSync(shellPath, "utf8");
  const start = source.indexOf("function addGivenAttributes(html, givens) {");
  const end = source.indexOf("\n\nfunction htmlWithGridCss", start);
  assert(start >= 0 && end > start, `addGivenAttributes not found in ${shellPath}`);
  const context = {};
  vm.runInNewContext(
    `${source.slice(start, end)}\nglobalThis.addGivenAttributes = addGivenAttributes;`,
    context,
    { filename: shellPath },
  );
  return context.addGivenAttributes;
}

function encoded(raw) {
  return JSON.stringify(raw)
    .replaceAll("&", "&amp;")
    .replaceAll('"', "&quot;")
    .replaceAll("<", "&lt;");
}

function openingTags(html, tag) {
  const marker = `<${tag} `;
  const tags = [];
  let from = 0;
  while (true) {
    const start = html.indexOf(marker, from);
    if (start < 0) return tags;
    const end = html.indexOf(">", start + marker.length);
    assert(end >= 0, `${tag} opening tag is not closed`);
    tags.push(html.slice(start, end + 1));
    from = end + 1;
  }
}

function givenValue(tag) {
  const marker = 'data-yumemi-given="';
  const start = tag.indexOf(marker);
  if (start < 0) return null;
  const valueStart = start + marker.length;
  const end = tag.indexOf('"', valueStart);
  assert(end >= 0, "data-yumemi-given value is not closed");
  return tag.slice(valueStart, end);
}

let failures = 0;

function run(name, test) {
  try {
    test();
    console.log(`${name}: PASS`);
  } catch (error) {
    console.error(`${name}: FAIL`);
    console.error(error.message);
    failures += 1;
  }
}

const addGivenAttributes = loadAddGivenAttributes();

run("GIVEN ESCAPE", () => {
  const raw = {
    ampersand: "&",
    quote: '"',
    lessThan: "<",
    dollarMatch: "$&",
    dollarPrefix: "$`",
    dollarSuffix: "$'",
  };
  const output = addGivenAttributes(
    '<pick-tag id="escape"></pick-tag>',
    [{ tag: "pick-tag", raw }],
  );
  const tags = openingTags(output, "pick-tag");
  assert(tags.length === 1, `expected one pick-tag, got ${tags.length}`);
  const value = givenValue(tags[0]);
  assert(value === encoded(raw), "special characters were not encoded exactly");
  assert(!value.includes("<"), "raw < escaped into the given attribute");
  assert(output.includes("&lt;"), "less-than escape is missing");
});

run("GIVEN SAME TAG ISLANDS", () => {
  const output = addGivenAttributes(
    '<pick-tag id="one"></pick-tag><pick-tag id="two"></pick-tag>',
    [
      { tag: "pick-tag", raw: { id: 1 } },
      { tag: "pick-tag", raw: { id: 2 } },
    ],
  );
  const tags = openingTags(output, "pick-tag");
  assert(tags.length === 2, `expected two pick-tag islands, got ${tags.length}`);
  assert(tags.every((tag) => givenValue(tag) !== null), "an island has no given attribute");
  assert(givenValue(tags[0]) === encoded({ id: 1 }), "first given crossed islands");
  assert(givenValue(tags[1]) === encoded({ id: 2 }), "second given crossed islands");
  assert(
    tags.every((tag) => tag.match(/data-yumemi-given=/g)?.length === 1),
    "an island received more than one given attribute",
  );
});

run("GIVEN EXISTING ATTRIBUTE", () => {
  const existing = encoded({ id: 0 });
  const output = addGivenAttributes(
    `<pick-tag data-yumemi-given="${existing}" id="one"></pick-tag><pick-tag id="two"></pick-tag>`,
    [{ tag: "pick-tag", raw: { id: 2 } }],
  );
  const tags = openingTags(output, "pick-tag");
  assert(tags.length === 2, `expected two pick-tag islands, got ${tags.length}`);
  assert(givenValue(tags[0]) === existing, "existing given attribute was changed");
  assert(givenValue(tags[1]) === encoded({ id: 2 }), "unmarked island did not receive given");
  assert(
    tags.every((tag) => tag.match(/data-yumemi-given=/g)?.length === 1),
    "an island received a duplicate given attribute",
  );
});

run("GIVEN CROSS TAG ORDER", () => {
  const output = addGivenAttributes(
    '<like-button id="one"></like-button><pick-tag id="two"></pick-tag>',
    [
      { tag: "pick-tag", raw: { id: 2 } },
      { tag: "like-button", raw: { id: 1 } },
    ],
  );
  const likes = openingTags(output, "like-button");
  const picks = openingTags(output, "pick-tag");
  assert(likes.length === 1 && picks.length === 1, "island count changed");
  assert(
    givenValue(likes[0]) === encoded({ id: 1 }),
    "an island earlier in the document than a preceding given lost its attribute",
  );
  assert(givenValue(picks[0]) === encoded({ id: 2 }), "given crossed tags");
});

if (failures > 0) {
  console.error(`GIVEN TESTS: FAIL (${failures} failed)`);
  process.exitCode = 1;
} else {
  console.log(`GIVEN TESTS: PASS (${shellPath})`);
}
