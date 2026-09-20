import { toList } from "../gleam.mjs";

export const resolve = (value) => Promise.resolve(value);
export const then = (value, next) => value.then(next);
export const commit = (context, carry) => context.commit(carry);
export const finish = (context) => context.finish();
export const reject = (context, stage) => context.reject(stage);

/// The Context contract for arrow reads. The runtime must implement
/// `relation(relation, keys)` and return the decoded target entities, one per
/// key and in key order. The framework never guesses property names, never
/// returns the relation value itself, and never treats a missing capability
/// as "already decoded".
export const relation = async (context, relation, keys) => {
  if (typeof context?.relation !== "function") {
    throw relationError(
      relation,
      "Context does not implement relation(relation, keys)",
    );
  }
  const wanted = [...keys];
  const rows = await context.relation(relation, wanted);
  if (!Array.isArray(rows)) {
    throw relationError(relation, "relation() must return an array");
  }
  return toList(rows);
};

export const relationBroken = (relation, keys, found) =>
  Promise.reject(
    relationError(
      relation,
      `expected ${[...keys].length} target row(s), found ${found}; keys=${JSON.stringify([...keys])}`,
    ),
  );

function relationError(relation, detail) {
  const error = new Error(
    `relation ${relation.service}/${relation.arrow} (${relation.from}.${relation.prop} -> ${relation.target}): ${detail}`,
  );
  error.code = "relation_contract";
  error.relation = {
    service: relation.service,
    query: relation.query,
    arrow: relation.arrow,
    from: relation.from,
    prop: relation.prop,
    target: relation.target,
  };
  return error;
}
