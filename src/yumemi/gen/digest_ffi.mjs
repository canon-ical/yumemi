import { createHash } from "node:crypto";

export function sha256_short(text) {
  return createHash("sha256").update(text, "utf8").digest("hex").slice(0, 12);
}
