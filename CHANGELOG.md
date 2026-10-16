# Changelog

Releases before 0.14.1 are described in the README sections (each names the version that brought it) and in the git history.

## 0.14.1 (2026-10-17)

Adds to 0.14.0 without changing what it promised: `Live` Blocks, their tokens, the socket and the signal are as they were.

- **The fragment answer serves `Fixed` Blocks too.** A GET of a page URL with `x-yumemi-block: <name>` answers for every `Fixed` Block of the Page's `sp` placements, on every face, not only for `Live` Blocks. Gate, Vars, session and reads are the same as for the page (the Block's read Service and the Page's and Layout's reads that are not `optional`); a Block that reads no Service is drawn from the Vars. The answer is `<style>` and `<yumemi-block name>` (`display: contents`, no token). Layout Blocks, `Widget` Blocks and names the Page does not place stay 404, before any read.
- **`yumemi.block` on every face with escapes.** `mount(element, yumemi)` gets `yumemi.block(name, { href })` whether or not the face has `Live`. For a `Fixed` Block it returns a detached `<yumemi-block href>` with its style rules added; calling it again with the same URL reads the placed element again and applies it in place (the morph of `Live`). It returns `null` when no fragment comes, and never reloads the page for a `<yumemi-block>`.
- **The client runtime is split.** `yumemi/front/block.mjs` holds the fragment fetch, the style rules and the morph; `yumemi/front/live_block.mjs` (tokens, socket, scroll, `el.fresh`) builds on it. A face without `Live` bundles `block.mjs` only, and only when it has escapes.
- **Generated output.** Faces whose Pages place `Fixed` Blocks get `block_<name>` functions in `src/gen/load/**`, a `blocks` table and the fragment answer in `src/gen/shell.mjs`, and the header check in `src/gen/gate.mjs`. The page HTML is unchanged.
