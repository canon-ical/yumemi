export const resolve = (value) => Promise.resolve(value);
export const then = (value, next) => value.then(next);
export const commit = (context, carry) => context.commit(carry);
export const finish = (context) => context.finish();
export const reject=(context,stage)=>context.reject(stage);

const rootArrowImplementation = async (context, service, arrow, root) => {
  if (typeof context.readRootArrow === "function") {
    return context.readRootArrow(service, arrow, root);
  }
  if (typeof context.decodeRootArrow === "function") {
    return context.decodeRootArrow(service, arrow, root);
  }

  const property = arrowProperty(arrow);
  const source = rootSource(root, property);
  if (source === undefined) {
    throw new Error(`root arrow source is missing: ${service}/${arrow}`);
  }
  const relation = source[property];
  if (typeof relation === "function") {
    return relation(context, service, arrow, root);
  }
  if (relation && typeof relation.read === "function") {
    return relation.read(context, service, arrow, root);
  }
  if (relation && typeof relation.resolve === "function") {
    return relation.resolve(context, service, arrow, root);
  }
  return relation;
};

function arrowProperty(arrow) {
  const marker = arrow.indexOf("To");
  if (marker < 1 || marker + 2 >= arrow.length) {
    throw new Error(`invalid root arrow: ${arrow}`);
  }
  const name = arrow.slice(marker + 2);
  return name[0].toLowerCase() + name.slice(1);
}

function rootSource(root, property) {
  if (!root || typeof root !== "object") return undefined;
  if (Object.prototype.hasOwnProperty.call(root, property)) return root;
  for (const value of Object.values(root)) {
    if (value && typeof value === "object" && property in value) return value;
  }
  return undefined;
}

function installRootArrow(context) {
  const implementation = (service, arrow, root) =>
    rootArrowImplementation(context, service, arrow, root);
  Object.defineProperty(context, "rootArrow", {
    configurable: true,
    enumerable: false,
    value: implementation,
    writable: false,
  });
  return implementation;
}

/// The framework owns this capability. Existing runtimes may expose a richer
/// implementation; a plain Context receives the decoded-root adapter above.
export const rootArrow = (context, service, arrow, root) => {
  const implementation =
    typeof context.rootArrow === "function"
      ? context.rootArrow
      : installRootArrow(context);
  return implementation(service, arrow, root);
};
