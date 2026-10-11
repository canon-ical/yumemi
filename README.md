# yumemi

**Have a sweet Gleam.** 設計を書けば、コードが生まれる。

A framework for [Gleam](https://gleam.run) on Cloudflare Workers. You describe an application in five words — Entity, Property, Type, Service, Authorization — and write each Service's logic; yumemi derives the Gleam code around that logic (types, codecs, reads, authorization checks, writes, the route table, SQL) and the HTTP entrance to it. MCP and CLI entrances are designed to come from the same description but are not generated yet.

Open source, coming soon. https://gleam.canon-ical.com/

## Status

**Under development.** The API may change between 0.x releases.

Extracted from the `framework/` directory of a production application on 2026-09-16, history included. Since 0.12 the module namespace is `yumemi/*` (it was `framework/*` up to 0.11) and the generator is the module `yumemi/gen` of the same package, so the Hex package [`yumemi`](https://hex.pm/packages/yumemi) carries both: the generator that runs is the yumemi version your `manifest.toml` locks. The database schema the runtime reads is still named `framework` (`db/queries/framework/*.sql`, keys such as `framework/outbox_claim`).

## Layout

| Module | What |
|---|---|
| `yumemi/spec` `yumemi/er` | Entity / Property / Type ── the model and its derivation |
| `yumemi/entry` `yumemi/verb` `yumemi/party` `yumemi/require` | Entrances and Authorization |
| `yumemi/step` `yumemi/effect` `yumemi/query` `yumemi/io` | Service logic: read / guard / apply / call / done |
| `yumemi/connector` `yumemi/page` `yumemi/blob` `yumemi/vector` | Connectors, SSR pages, R2, Vectorize |
| `yumemi/secret` `yumemi/sealed` `yumemi/time` | Secrets, sealed values, time |
| `yumemi/front` `yumemi/front/*` | Faces: Layout, Page, Frame, Style, the client runtime (`navigate.mjs`) |
| `yumemi/server` `yumemi/server/*.mjs` `yumemi/gate` | The back-end runtime the generated code imports, and a face's gate |
| `yumemi/gen` | The generator (reads the app's Gleam sources, writes the derived Gleam, SQL and JS) |

## The generator

Run it from any package that depends on `yumemi` (the app's `api/`, or a face):

```
gleam run -m yumemi/gen -- <app dir> <out dir>
```

For example, in a repository with `api/` and faces beside it, `cd api && gleam run -m yumemi/gen -- . ..` writes the back under `api/` and each face's files under the face's package. It exits non-zero when the output is incomplete; the exit code says who fixes it (`yumemi/gen/stop`).

A face's `priv/static/_yumemi/client.mjs` is bundled with the esbuild the face's lockfile installed (`<face>/node_modules/.bin/esbuild`). When it is missing the generator stops with exit 3 and names the path — add `esbuild` to the face's `devDependencies` and run `npm ci` in the face. It does not fall back to `npx`.

## Developing yumemi

```
npm ci        # the esbuild the generator tests bundle with
gleam test    # the runtime checks and the generator tests (fixtures in gen/fixtures)
```

`gen/fixtures` (sample apps) and `gen/scripts` (one-off verification scripts) are not part of the Hex package.

To generate a fixture in place, run the generator from the root (`gleam run -m yumemi/gen -- gen/fixtures/article gen/fixtures/article`). The fixture faces have no `package.json`, so first link the root's esbuild into each face that has a client (`public` in `article`: `mkdir -p gen/fixtures/article/public/node_modules/.bin && ln -s "$PWD/node_modules/.bin/esbuild" gen/fixtures/article/public/node_modules/.bin/esbuild`); without it the generator stops with exit 3. When yumemi's `[dependencies]` change, run `gleam update yumemi` in each fixture face, or its client build cannot see the new packages.

## `yumemi/front` ── Elements and attributes (0.12)

A Block, a Layout's Block and the docs page are written with yumemi's own element tree; a ★ module imports `yumemi/front/el`, `yumemi/front/html`, `yumemi/front/attr` and `yumemi/front/css`, and never `lustre` or `sketch/lustre` (the generator stops on that import, exit 4, article 1; a face's `gleam.toml` listing `lustre` / `sketch_lustre` stops too, article 2). The only exception until stage C is a 0.11-shaped interactive Component (a `components/` module with `pub fn app`) — it still runs on lustre in its shadow root, and the generator prints how many such modules a face has (`[exit 0 警告] <face>: 第 1・2 条の例外 ..: N module`).

```gleam
import yumemi/front/attr
import yumemi/front/css
import yumemi/front/el.{type Element}
import yumemi/front/html

const card = [css.Color(css.Token("ma-color-ink")), css.Space(css.Padding, css.Px(16.0))]

pub fn view(it: In) -> Element {
  html.section(css.class(card), [attr.data("slug", it.slug)], [
    html.h1_([], [el.text(it.title)]),
    html.a_([attr.href(it.link)], [el.text("more")]),
  ])
}
```

- `el.Element` and `el.Attribute` are opaque and take no type parameter. `el.text` / `el.each` / `el.none` / `el.fragment`, the framework words (`el.opener` / `el.closer` / `el.badge` / `el.each_modal` / `el.img`) and `el.to_string` (for tests) are public; the rest of `el` is `@internal` and a ★ calling it stops the generator (article 3).
- `html` has the 53 tags musearch uses plus `svg` / `path`, each as `tag(class, attributes, children)` and `tag_(attributes, children)`, with sketch_lustre's names and argument order. There is no `style`, `script` or `link`.
- `attr` has typed attributes with lustre's names, `data(name, value)`, `aria(name, value)` and `role(attr.Status | ..)`. There is no free-name attribute, no `class` (a class is the tag's first argument, `css.class(styles)`), no `style` and no event.
- Rendering never fails a page: a `data` / `aria` name that is not `[a-z][a-z0-9-]*` drops that attribute (a literal one stops the generator, article 7); `href` / `src` are dropped unless the scheme is `http`, `https`, `mailto`, `tel` or none (a relative URL); the same attribute written twice keeps the last one (written twice literally in one list stops the generator, article 8); `</` and `<!--` inside the generated `<style>` become `<\/` and `<\!--`. Fragments leave no comment markers, and a `textarea` / `pre` whose text starts with a newline keeps it.
- Until stage C a Block places a 0.11 interactive Component with `el.legacy_island("like-button", [#("slug", it.slug)])` (a tag that is not a custom-element name renders nothing; an `on*` / `style` / `class` / `srcdoc` / non-`[a-z][a-z0-9-]*` argument is dropped).

### The raw-CSS escape (0.12)

`shell.stylesheets` (below) and `el.stylesheet(el.static_sheet("fonts/mincho.css"))` in a Block load a `.css` file from the face's `priv/static/`. Both are an escape hatch that the generator checks and counts:

- the file must exist under `priv/static/` (exit 3, article 28) and the `static_sheet` path must be a string literal (exit 4, article 31);
- no selector may name generated output — `[data-yumemi-…]`, a generated class `.css-<8 hex>`, or an element whose name starts with `yumemi-` (exit 4, article 29). An interactive Component's own tag (`like-button`) and its `:state()` are fine, and so is reading `var(--yumemi-theme-*)` in a declaration;
- no `@import` (exit 4, article 30);
- the rules are counted per face — each top-level block is one rule, an `@media` block is one — and printed as a warning (exit 0): `[exit 0 警告] <face>: 生の CSS の逃げ道 <n> file(..)、規則 <n>`, also in `_diagnostics.txt`.

## `yumemi/front` ── Shell: the home screen, the service worker and the stylesheets (0.11.12, 0.11.15)

A face's `src/shell.gleam` holds the constants the generator puts in every page's `<head>`. `lang`, `title` and `theme` are required (as before; from 0.12 `theme` is `pub const theme: theme.Defaults = theme.Defaults(background: "#FAF7F0", text: "#3D2419", accent: "#A93632", background_image: None)` — the three colours are `#rrggbb` literals, exit 4 otherwise, and `background_image` is `None` or `Some("<path under priv/static>")`, exit 3 when the file is missing; article 26). Five more are optional `String` constants; each one that is present adds one element after the `<title>`, in this order, and a shell without them generates exactly what 0.11.11 did:

| Constant | Goes out as |
|---|---|
| `manifest` | `<link rel="manifest" href="..">` |
| `theme_color` | `<meta name="theme-color" content="..">` |
| `icon` | `<link rel="icon" href="..">` (the favicon) |
| `apple_touch_icon` | `<link rel="apple-touch-icon" href="..">` |
| `service_worker` | the generated `priv/static/_yumemi/client.mjs` calls `navigator.serviceWorker.register("..")` once when it loads |

`stylesheets` (0.11.15) is an optional `List(String)` constant: one `<link rel="stylesheet" href="..">` per item, in list order, after the elements above. From 0.12 each file is checked and counted as the raw-CSS escape (above). Put the face's site-wide stylesheets here rather than in a Block: a `<link>` in `<head>` holds the first paint until it has loaded, and client navigation keeps it (see Client navigation below), where a `<link>` in `<body>` is rebuilt — and revalidated — on every navigation. An empty list adds nothing.

```gleam
pub const manifest: String = "/manifest.webmanifest"
pub const theme_color: String = "#A93632"
pub const icon: String = "/favicon.svg"
pub const apple_touch_icon: String = "/apple-touch-icon.png"
pub const service_worker: String = "/sw.js"
pub const stylesheets: List(String) = ["/brand/tokens.css", "/brand/site.css"]
```

- The files themselves (the manifest, the icons, `sw.js`) are the face's static assets under `priv/static/`; the generator only links them.
- The registration does nothing where `navigator.serviceWorker` is missing, and a failed registration is swallowed (the page keeps working). Client navigation does not reload `client.mjs`, so it registers once per page load. A face without islands gets a `client.mjs` that only registers the worker (and the page loads it); a face with neither gets no `client.mjs`, as before.
- Client navigation keeps the `<head>` elements the next page also has and swaps the rest, so each element stays exactly once after a navigation.
- A constant that is present but is not a non-empty `String` constant (another type, or `""`) stops the generator like a missing `title`: exit 3, `<face>/src/shell.gleam: <name> は空でない String の定数で書く`. For `stylesheets` the same holds when it is not a list literal of non-empty strings: `<face>/src/shell.gleam: stylesheets は空でない String の List の定数で書く`.

## `yumemi/front` ── Client navigation (0.11.4, 0.11.15)

The generated client calls `yumemi/front/navigate.mjs`'s `start({routes, csp, boot, pageview})`. `routes` lists every Page route of the face; `csp` maps each route of a gate `frame_src` Page to the `content-security-policy` value the gate sends with it (`frame-src https://<host> ..` from the entry's `frame_src` hosts). A face without such Pages gets no `csp` key, exactly as in 0.11.14.

- **Which clicks.** A plain left click on a same-origin link, from a routed Page to a routed Page, whose destination has the same CSP as the Page that loaded the current document (both none, or the same value). A CSP header only takes effect on a page load, so a link to a Page with another CSP — or from a Page without one to a Page with one — is a page load, and the destination's policy holds. Modified clicks, `target`, `download` and links to unrouted paths are page loads, as before.
- **Which responses.** One fetch with `x-yumemi-navigate: 1` (the gate, the adult declaration and the session go through the server as before). It falls back to a page load on a redirect (a gate's 302, e.g. to `/enter`), a non-200, a non-HTML body, a `content-security-policy` header that differs from the route table's value for that Page (or is present where the table has none, or missing where it has one), a page with scripts other than the client, or an already-registered given island. 0.11.14 fell back on any CSP header.
- **The head.** Elements whose `outerHTML` is the same in the current and the next `<head>` stay where they are (a stylesheet is not re-requested); the others are removed or inserted at the next page's positions, so the order follows the next page. The client script stays.
- **Stylesheets load before the body changes.** A stylesheet new to `<head>`, and a copy (in `<head>`, marked `data-yumemi-hold`) of each stylesheet that only the next page's `<body>` links (an article's font CSS, say), is inserted with `media="not all"` and awaited (load or error, at most 3 seconds); then its `media` is restored, the old head elements leave and the body is swapped. A copy is removed once the body's own `<link>` has loaded. The old page stays on screen meanwhile, so no unstyled page shows; the swap waits for those downloads.
- **Pageviews, back / forward and reload after a write** are unchanged: the gate's mark in `<head>` counts the navigation (`kind` `spa`), back / forward take the same path, and `navigate.reload()` refetches a routed Page in place (`kind` `reload`).

## `yumemi/front` ── Page theme: where the colours come from (0.11.13, 0.12)

`Page(.., theme: Some(name), ..)` paints the page with a `yumemi/front/theme.PageTheme` read on the server; `theme: None` paints the shell's `theme` defaults only.

```gleam
// yumemi/front/theme
pub type PageTheme {
  PageTheme(background: Option(color.Color), background_image: Option(blob.Blob),
            text: Option(color.Color), accent: Option(color.Color))
}
```

- **Colours are a type.** `yumemi/front/color.Color` is opaque: `color.parse` accepts `#` and six hex digits only (`"#fff;}</style>"` is an `Error`), and the output is rebuilt from the parsed digits (lower case). An Entity or a Service `Out` holds `theme.PageTheme` (or `color.Color`) directly; the face copies (`src/gen/out/*`) keep yumemi's types instead of `String`, and the back's codec reads a stored colour with `color.parse`.
- **Output:** four custom properties on `body` — `--yumemi-theme-bg`, `--yumemi-theme-bg-image` (`url("..")`, the URL built by the app's `media.url(blob, media.W1600)` as before), `--yumemi-theme-text`, `--yumemi-theme-accent` — and, on a page with a background image, `data-yumemi-theme-image` on `body`. A ★ reads them with `css.Theme(css.ThemeBackground | ThemeText | ThemeAccent)` and `css.State(css.ThemeImage, ..)`, never by name.
- **Which Service and where in its `Out`:** unchanged from 0.11.13 — the first source whose `Out` reaches a `PageTheme` through labelled record fields (through `Option`, records and aliases), `name` choosing the last field's label — except that the field must be yumemi's `theme.PageTheme` (an app type that is merely called `PageTheme` is not taken). When no source of a `theme: Some(name)` Page reaches one, the generator stops (exit 4, article 27).

## `yumemi/front` ── Style (0.11.10)

`yumemi/front/css`'s `Style` is the typed vocabulary a Page / Area / component carries; `yumemi/front/sketch_css` maps it to CSS (sketch classes; a 0.11 island's Style still lands in the island's shadow `<style>`). `css.class(styles)` makes the `Class` a tag takes. Every word also works inside `State(Hover / Focus / FocusVisible / HoverCapable / Disabled / Current / Waiting / Succeeded / Failed / ThemeImage, ..)` and `Responsive(SP / PC / Tablet, ..)`.

Colours are a closed type, `css.Paint` (0.12; before, a string passed straight through):

| Paint | CSS |
|---|---|
| `Hex("#a1b2c3")` | the hex, lower case — a string literal of `#` and six hex digits (exit 4 otherwise, article 23) |
| `Token("ma-color-ink")` | `var(--ma-color-ink)` — the name is `[a-z0-9-]+` (exit 4 otherwise, article 24) |
| `Theme(ThemeBackground / ThemeText / ThemeAccent)` | `var(--yumemi-theme-bg)` / `-text` / `-accent` (Page theme, above) |
| `Mix(a, b, percent)` | `color-mix(in oklab, a percent%, b)` — `percent` 0–100 (exit 4 otherwise, article 25) |
| `Transparent` / `CurrentColor` | `transparent` / `currentcolor` |

| Style | CSS |
|---|---|
| `Color(value)` | `color` |
| `Background(value)` | `background-color` |
| `Border(edge: AllEdges / TopEdge / BottomEdge, width, style: Solid / Dashed / Dotted, color)` | `border` / `border-top` (0.12) / `border-bottom` (e.g. the 2px tab underline) |
| `TextAlign(align: TextStart / TextCenter / TextEnd)` | (0.12) `text-align: start / center / end` |
| `Outline(width, offset, color)` | `outline-style: solid` / `outline-width` / `outline-offset` / `outline-color` — the focus ring, inside `State(FocusVisible, ..)` (0.11.14; `State(Focus, ..)` also keeps it after a tap) |
| `Space(property:, value:)` | `margin` / `padding` / `gap` / `width` / `height` / `border-radius`, and (0.11.7) `min-width` / `min-height` / `max-width` |
| `Text(family:, size:, weight:, line_height:)` | `font-family` (`System` / `SansSerif` / `Serif` / `Monospace`, or `Named("var(--ma-font-ui)")` / `Named("\"Noto Sans JP\", sans-serif)")`), `font-size`, `font-weight` (`Normal` 400 / `Medium` 500 / `SemiBold` 600 / `Bold` 700), `line-height` |
| `Crop(fit: Cover / Contain / Fill / ScaleDown / FitNone, ratio: Ratio(w, h))` | `object-fit` and `aspect-ratio` |
| `Sizing(box: BorderBox / ContentBox)` | (0.11.8) `box-sizing` — `BorderBox` counts padding and border inside `width` / `min-height`, so an input or an `<a>` button with `min-height: 48px` and padding stays 48px |
| `Marker(marker: NoMarker)` | (0.11.8) `list-style: none` — drops the `ul` / `li` bullet (clear the indent with `Space(Padding, Px(0.0))`) |
| `Decoration(line: NoDecoration / Underline)` | (0.11.8) `text-decoration: none` / `underline` — e.g. a row link without the underline, underlined again inside `State(Hover / Focus, ..)` |
| `Wrap(wrap: Anywhere / BreakWord / WrapNormal)` | (0.11.10) `overflow-wrap: anywhere` / `break-word` / `normal` — `Anywhere` breaks a long URL or an unbroken word at the line's width, so the row's `scrollWidth` stays its `clientWidth` (it also lowers the min-content width, so the word does not widen a flex / grid item); `BreakWord` breaks it too but keeps the min-content width |
| `State(FocusVisible, styles)` | (0.11.14) `:focus-visible` — the focus ring for keyboard focus only. `Focus` (`:focus`) also matches after a tap or a click, so a ring put there stays on a tapped button; put the ring here instead |
| `State(HoverCapable, styles)` | (0.11.14) `@media (hover: hover) { .class:hover { .. } }` — hover on devices that can hover (a mouse). On a touch screen `:hover` stays true after a tap, so a `Hover` background stays on the tapped button; this one is not applied there. Same specificity as `Hover` (the class plus `:hover`), so it beats the class's own background. Inside `Responsive(at, ..)` it becomes one media, `@media (<at>) and (hover: hover)` |
| `State(Current, styles)` | (0.11.9) `[aria-current]:not([aria-current="false"])` — the item that is where the user is (`aria-current="page"`, also `step` / `location` / `true`). Mark the nav item with `aria-current` (a Layout block learns the page from `CurrentRoute`, below) and give it e.g. the 2px underline with `Border(BottomEdge, ..)` |
| `State(Waiting / Succeeded / Failed, styles)` | (0.12) inside an interactive Component whose custom state is `waiting` / `ok` / `error`. Written twice: `@supports selector(:state(x)) { .class:is(:state(x) *) {..} }` and `@supports not selector(:state(x)) { .class:is([data-yumemi-state~="x"] *) {..} }` for browsers without `:state()`. Inside `Responsive(..)` the two selectors are written without `@supports` (sketch drops an at-rule inside a media) |
| `State(ThemeImage, styles)` | (0.12) `.class:is([data-yumemi-theme-image] *)` — on a page with a background image |
| `Flow(..)` `State(..)` `Responsive(..)` | layout, interaction states, breakpoints (unchanged). `Animation` was removed in 0.12 (no `@keyframes` was ever emitted) |

Lengths (`css.Length`) are `Px(n)` / `Rem(n)` and, from 0.11.9:

| Length | CSS |
|---|---|
| `Var(name)` | `var(--name)` — e.g. `Var("ma-space-2")`. The name passes only `[a-z0-9-]`; any other name (`;`, `}`, `)`, a space, upper case, empty) is written as `unset` by `sketch_css`, and the generator stops on it in an Area's `gap` |
| `Env(SafeTop / SafeRight / SafeBottom / SafeLeft)` | `env(safe-area-inset-top, 0px)` … (0px where the device has no safe area) |
| `Dvh(n)` | `n dvh` — e.g. `Space(MinHeight, Dvh(100.0))` for a short page that still fills the screen |

They work everywhere a Length does: `Space`, `Text`, `Border`, `Outline`, `Flow` gaps, and an Area's flow `gap` in the generated grid CSS (literal or a `style` constant).

## `yumemi/front` ── Grid style and the bottom bar (0.11.10)

- **`StyledFrame(areas:, placements:, cols:, rows:, template:, style:)`** — a `Frame` (sp, pc or tablet) whose `style: List(css.Style)` goes on the grid element itself (`data-yumemi-grid`, the Layout's or a Page's). The other fields are those of `Frame`, and a plain `Frame` (or `style: []`) generates exactly what 0.11.9 did. It is a second constructor rather than a new field, so every existing `Frame(..)` keeps compiling. Write the style like an Area's: a `style` constant (`style: style.shell`) or a list of them (`style: [style.shell]`); the generator stops on anything else. The sp Frame's style holds at every width; a pc / tablet Frame's style is wrapped in `Responsive(PC / Tablet, ..)` (the same widths as the grid's media rules). The style becomes a sketch class on the grid element, and every Area keeps its own class, so the two never share a rule. Columns, rows and `gap` stay with the Frame's fields (the generated grid CSS writes them); use the style for the rest. `front.frame_style(frame)` reads it (`[]` for `Frame`).
  - The screen-tall shell: `style.shell = [css.Space(css.MinHeight, css.Dvh(100.0))]` with `rows: [track.Auto, track.Fr(1), track.Auto]` — the grid is at least the screen tall and the body row takes what is left, so a short page still puts the last row at the bottom of the screen; a long page is laid out as before.
- **`pin: BottomFlush`** — a bar stuck to the very bottom of the screen: `position: sticky; bottom: 0; padding-bottom: env(safe-area-inset-bottom, 0px); z-index: 3`. Its background reaches the bottom edge, and its content sits above the iPhone home indicator. The bottom padding of the Area is the safe-area inset (it wins over an Area style's `padding`), so put any further space inside the bar's block. `Bottom` is unchanged (`bottom: env(safe-area-inset-bottom)`, floating above the inset).

## `yumemi/front` ── Layout vars and Overlay (0.11.9)

- **`Var(name, CurrentRoute)`** — the route spelling of the Page being drawn, as the generated route table writes it (`/rosters/:id`, `/`). It is a constant the generator knows per Page; the request's argument values and query never enter it. It can sit in a Layout (where `Path` / `Query` / `Session` cannot) or in a Page, and arrives as a `String` block arg of the same name — a header block compares it with its links' routes to set `aria-current="page"`.
- **`pin: AnchoredOverlay(side: Below / Above, align: AlignStart / AlignEnd)`** — an Overlay Area that opens next to the `el.opener` button that opened it, below or above it, lining up its start or end edge with the button's. It is an Overlay in every other respect (`el.opener` / `el.closer`, popover, not in the grid). The generated CSS uses CSS anchor positioning inside `@supports (anchor-name: ..)` (`position-area`, `position-try-fallbacks: flip-block`) and leaves the backdrop clear. A browser without anchor positioning opens it like `Overlay`: centred by the UA, with the darkened backdrop. With several openers for the same Area the anchor is the last one in document order. `Overlay` and `[popover]::backdrop` are unchanged.

## `yumemi/front` ── Area flow (0.11.8)

An Area's `flow` in a Layout or a Page's Frame now reaches the generated grid CSS (the `<style>` that `htmlWithGridCss` puts in SSR pages and `_yumemi/style.css`, which carry the same text): the Area's rule gets the flow's declarations after `grid-area`, so the blocks placed in the Area are laid out by it. Before 0.11.8 the Area stayed `display: block` and the flow was ignored.

| `flow` | declarations in the Area's rule |
|---|---|
| `Stack(gap:)` | `display: flex; flex-direction: column; align-items: stretch; gap` — blocks keep the Area's full width |
| `Row(gap:, wrap:)` | `display: flex; flex-direction: row; flex-wrap: wrap / nowrap; gap` |
| `Grid(cols:, gap:)` | `display: grid; grid-template-columns: repeat(cols, minmax(0, 1fr)); gap` |
| `GridTracks(cols:, gap:)` | unchanged (already written since 0.11.x: `display: grid`, the tracks, `gap`) |
| `Scroller` | `display: flex; flex-direction: row; overflow-x: auto` |

- `gap` is a literal (`css.Px(..)` / `css.Rem(..)`) or a constant of the app's `style` module (`style.s2`). A gap the generator cannot read leaves the Area's rule without flow lines (as before).
- Every variant writes its direction, so a `pc` / `tablet` Frame that gives the Area another flow overrides the `sp` one inside its media rule. An Area shown only at a breakpoint (hidden elsewhere) keeps `display: none` outside it; inside the media rule its flow's `display` shows it, and no `display: block` is added.
- An Area pinned `Overlay` gets no flow lines (its display stays with the overlay). `pin` and `style` output is unchanged.
- `yumemi/front.area_flow_css(flow)` returns the declarations for one `css.Flow`.

## `yumemi/server` ── what the app must provide (0.11.1)

The back-end runtime (`yumemi/server/*.mjs`) is JavaScript that the generated `src/gen/*.mjs` imports. It knows no application names: route names, cookie names, key bindings and the party a queue consumer reads its borrowed root as come from the app's `src/server.gleam` (`attached_roles`, `browser`, `hooks`, `roots`' `QueueParty`). The generated face gate (`<face>/src/gen/gate.mjs`, declared in `<face>/src/gate.gleam` with `yumemi/gate`) reads the session through the `ReadSession` attached route. Gleam packages cannot declare npm dependencies, so the app supplies the following itself.

Generated live modules (0.11.2) send Args by their declared type: `Bool` as a JSON boolean (the live field's `"true"` / `"false"`), `Int` / `Float` as numbers. On a `GET` route the Args that are not path holes go on the query string (an empty `Option` is left out), and the runtime reads `bool` (`true` / `false`) and `float` spellings from the query of `GET` / `HEAD` requests. `POST` / `PUT` / `DELETE` bodies are read as JSON as before.

A live field for a `List(X)` Arg (X a scalar, value type, id or enum) holds a JSON array of strings (`["a","b"]`, an empty field is `[]`); each item is sent by X's rule. A field for a record, tuple, `Dict` or a `List` of those holds the JSON body itself (for example `{"background":"#112233"}`), which is sent as is and read by the back-end decoder. A field that does not parse is sent as a string, and the back end answers `invalid_argument`. Sum types with several constructors are sent as strings.

A Service whose logic runs `step.commit` and continues after it (and is not a queue consumer that only uses the commit as a boundary) ends in `Accepted` over HTTP: the runtime answers 202 with a one-field body (`{"<root>": id}`, a `respond` hook may rename the field). The generated live for such a Service (0.11.3) holds `Reply` instead of the Service's `Out`: `Accepted(id)` for the 202 body and `Replied(out)` for a 200 that ends before the commit. Both arrive as `Done(Ok(_))` and go on to `after_send` (for example `ReloadPage`). Lives of other Services are unchanged.

0.11.4 adds, without changing the existing public types:

- **Reads time out and retry once.** `driver.mjs` cuts a read-only statement (one `SELECT` / `WITH` / `VALUES` / `TABLE` with no write keyword — `INTO` and row locks count as writes — and no call to a function outside the built-in allow list, read after one pass that strips strings, quoted identifiers and comments; see `yumemi/server/read_retry.mjs`) after `DATABASE_READ_TIMEOUT_MS` (default 10000) and retries it once when the failure is outside the database (timeout, fetch failure, HTTP 5xx; not an SQLSTATE). Writes and transactions are never retried and get no timeout. Every failure outside the database, read or write, is logged as one JSON line (`{"yumemi":"driver.failed",kind,key,attempt,ms,code,status,name,body}`, `kind` is `read` / `write` / `transaction`) with the response body.
- **Attached routes with a framework role that reads a body** send it: the live for a `SwitchSubject` route has `Args(kind, id)` and sends `{kind, id}`. Other attached lives are unchanged (no Args, `null` body).
- **The `BlobCopy` live copies a URL.** Besides the file upload (`Send`), `copy_from(state, url)` sends `{from: url}` to the same route and reads `{key}` into `Done(Ok(key))`.
- **Split records decode.** A record Property stored with `Split` is rebuilt from its columns in `src/gen/codec.mjs`.
- **Islands render sketch classes.** The generated client registers each island through `yumemi/front/island_style.mjs`'s `styled(app)`: the island gets its own sketch stylesheet while its view runs, and the CSS goes into a `<style>` inside the island (only when the island uses classes and does not render its own stylesheet).
- **Client navigation between Pages.** The generated client calls `yumemi/front/navigate.mjs`'s `start({routes, boot, pageview})`. A plain left click on a same-origin link, from a Page to a Page that are both in the face's route table (minus the gate's `frame_src` Pages), fetches the next page with one request (the gate, the adult declaration and the session go through the server as before), swaps `<head>` and `<body>`, re-runs the island registrations and pushes history; back / forward do the same. A redirect, a non-200, a `content-security-policy` header, a page with scripts other than the client, an already-registered given island, a modified click, `target` or `download` fall back to a page load.
- **Pageviews count once per navigation.** The navigation fetch carries `x-yumemi-navigate: 1`; for it the gate puts `<meta name="yumemi-pageview">` in `<head>` instead of the pageview script (same conditions: adult session, 200 HTML, a `pageview` Page) and adds `vary: x-yumemi-navigate`. The client posts the pageview (`kind` `spa`) only after it swapped that page in; a fallback to a page load gets the script as before.
- **Reload after a write stays in the page.** An island's `yumemi-done` calls `navigate.reload()`: on a routed Page it refetches the current URL the same way (no history entry, scroll kept, pageview `kind` `reload`); otherwise it reloads the page.

0.11.5 adds, without changing or removing the existing public types:

- **Gate: send back with a return path.** `Fail.RedirectBack(location, param)` answers 302 to the face path `location` and puts the request's path + search, URL-encoded, in the query `param` (joined with `&` when `location` already has a query). When the request's path + search is not a face path (the `SafeParam` check: it starts with `//`, or has a backslash or a control character) the param is left out, so the gate never sends anyone to another origin. `location` must start with `/`, not `//`, and carry no backslash, control character or `#`; `param` is `[A-Za-z0-9_.-]+` — the generator stops otherwise (exit 4). A client navigation fetch gets the same 302; the client falls back to a page load as for any redirect.
- **Gate: a fixed redirect that keeps the query.** `To.FixedKeep(location)` answers 302 to `location` plus the request's query. `Fixed(location)` is unchanged (drops the query). The hash never reaches the server; on a page load the browser carries the original hash across a redirect without one, and a client navigation falls back to that page load. `location` follows the same face-path rule as `RedirectBack` and has no `?` either.
- A gate that uses neither word gets the same `gate.mjs` as 0.11.4, character for character.
- **A missing root statement stops generation.** A Service with a root Entity reads its root with `db/queries/<service>/root.sql`. Without it the runtime answers 503, so the generator now stops with exit 3 naming the Service. Services that build their root another way are not stopped: a Service answered by a `service_<name>` hook (a Durable Object port), a queue consumer that borrows the root of a Service that has a root statement and calls it through the queue, `Rootless`, and roots with no Entity (`Carried` only).
- **Faces narrower than the entries are enforced at runtime.** A Service that declares two or more faces gets `entries: [..]` in `src/gen/registry.mjs` when an entry outside its faces could still route it (same credential kind; a `ReadOnly` entry only for a Read Service), and check 7 answers 403 on any other entry. A Service with one face keeps `entry: '<name>'` as before (the same face repeated counts as one); a Service whose faces hold every entry that could route it (all four session faces in our in-house service) gets neither.

0.11.6 changes when the outbox is swept, without changing the public types:

- **A request that wrote to the outbox sweeps it, whatever its status.** The fetch handler wraps the request's database handle and notes every statement or transaction that inserts into `framework.outbox` (`INSERT INTO framework.outbox`, also inside a `WITH`, in generated and hand-written SQL alike; comments and string literals do not count, quoted identifiers are not recognised) and resolves, that is, commits. After such a request — 200, 4xx, 5xx or a thrown error — `waitUntil` runs the sweep, as a 202 always did (202 still sweeps). A request that only reads, or whose outbox insert failed or rolled back, does not sweep. The cron sweep is unchanged.
- **Each row is sent once by overlapping sweeps.** The sweep claims a row with `framework/outbox_claim` (a conditional `UPDATE … SET sent_at=now() … RETURNING id`) before it sends it, and skips a row it could not claim. A second sweep that reaches the same row waits for the first one's row lock, re-reads the condition and gets no row. `framework/outbox_sent` is no longer called. A row whose send fails after the claim waits out the resend window (1 hour) like a lost message and is sent by the first sweep after it (a request that sweeps, a 202 or the cron); 0.11.5 resent it on the next sweep. Consumers stay idempotent.
- The generator adds a default `framework/outbox_claim` statement to `src/gen/sql.mjs` when the app has no `db/queries/framework/outbox_claim.sql`; the app's own file wins. Its resend window (1 hour) must match the app's `framework/outbox_sweep`.

0.11.7 adds, without changing the existing variants' meaning or output:

- **Style grows the look vocabulary** (see the Style section above): `Background`, `Border` (all edges or bottom only), `Outline` (the focus ring, always `outline-style: solid` with `outline-offset`), `min-width` / `min-height` / `max-width` in `Space`, `Named(..)` font families (a CSS variable or a family name), `SemiBold` (600), and `Crop` (`object-fit` + `aspect-ratio`). Color values stay strings (`var(--ma-*)`, `color-mix(..)` pass through). Generation from an unchanged app is byte-identical.

0.11.8 adds, without changing the existing variants' meaning or output:

- **Style:** `Sizing` (`box-sizing`), `Marker(NoMarker)` (`list-style: none`), `Decoration` (`text-decoration: none` / `underline`), all usable inside `State(..)` / `Responsive(..)`.
- **Area flow reaches the grid CSS** (see the Area flow section above). Regenerating an app changes only the Area rules of the grid CSS.

0.11.9 adds, without changing the existing variants' meaning or output:

- **Layout knows the page:** `front.From` gains `CurrentRoute` (see Layout vars above). The shell carries it as a constant per page; the shell's branch for it is written only for a face that uses it.
- **Style:** `State(Current, ..)` (`aria-current`), and the lengths `Var` / `Env` / `Dvh`, read by the generator in Area gaps and `style` constants too.
- **Overlay:** `pin: AnchoredOverlay(..)` opens next to its opener (CSS anchor positioning; centred as before without it).
- Regenerating an app that uses none of these is byte-identical.

0.11.10 adds, without changing the existing variants' meaning or output:

- **Grid style:** `front.StyledFrame(.., style:)` puts a Style on the grid element (see Grid style above).
- **Pin:** `BottomFlush` (bottom 0, safe area as inner padding); `Bottom` is unchanged.
- **Style:** `Wrap(Anywhere / BreakWord / WrapNormal)` (`overflow-wrap`).
- Regenerating an app that uses none of these is byte-identical.

0.11.11 changes documentation only (one README sentence and one source comment). No code, type or generated output changes.

0.11.12 adds, without changing the existing output:

- **Shell:** the optional constants `manifest`, `theme_color`, `icon`, `apple_touch_icon` (elements in `<head>`) and `service_worker` (registered by the generated `client.mjs`) (see Shell above). A wrong type or an empty string stops with exit 3.
- Regenerating an app that uses none of these is byte-identical.

0.11.13 fixes `Page(theme: Some(name))`, which always gave `None` at runtime (the shell looked up `name` at the top of the last source's `Out`):

- **Page theme:** the theme is taken from the Service the generator picked, along the field path to its `PageTheme` (see Page theme above). Only the generated `shell.mjs` of a face with a themed Page changes (the theme row and the `pageTheme` lookup).
- Regenerating a face with no `theme: Some(..)` Page is byte-identical.

0.11.14 adds, without changing the existing variants' meaning or output:

- **Style:** `State(FocusVisible, ..)` (`:focus-visible`, keyboard focus only) and `State(HoverCapable, ..)` (`:hover` inside `@media (hover: hover)`), so a tapped button keeps neither the focus ring nor the hover background (see Style above). `Hover`, `Focus`, `Disabled` and `Current` render exactly as in 0.11.13.
- Regenerating an app that uses none of these is byte-identical.

0.11.15 changes client navigation and adds a Shell constant:

- **Pages with a CSP navigate on the client.** The gate's `frame_src` Pages are now in the client's route table with their CSP (`csp` in `start`), and the client takes a navigation only between Pages with the same CSP as the one that loaded the document, checking the response's header against the table (see Client navigation above). A face whose Pages all carry the same `frame_src` navigates on the client everywhere. Only the generated `client.mjs` of a face with `frame_src` Pages changes (the routes line).
- **The head is diffed, and stylesheets are awaited.** Navigation keeps identical `<head>` elements in place, and swaps the body only after new head stylesheets and the next body's stylesheets have loaded (see Client navigation above).
- **Shell:** the optional constant `stylesheets: List(String)` (`<link rel="stylesheet">` in `<head>`) (see Shell above).
- Regenerating a face with no `frame_src` Page and no `stylesheets` is byte-identical (the framework code in the bundled `client.mjs` changes with the version, as with any version that changes `navigate.mjs`).

**Imports outside the package**

| Import | Imported by | Provided by |
|---|---|---|
| `@neondatabase/serverless` | `yumemi/server/driver.mjs` (Neon HTTP transport, `database(env, observe)`) | the app's `package.json` |
| `cloudflare:workers` | `yumemi/server/worker.mjs` (`DurableObject` / `WorkerEntrypoint`) | the Workers runtime (wrangler / workerd); not an npm package, so modules that import `worker.mjs` (the generated `shell.mjs`) do not load under plain node |

**SQL** — the runtime runs these keys through the app's SQL bundle (`src/gen/sql.mjs`, built from `db/queries/**`). The app writes them as `db/queries/framework/<name>.sql` against its own `framework` schema (DDL is the app's). Holes are positional, in the order below.

| Key | Holes | Used for |
|---|---|---|
| `framework/session_resolve_staff` | session id, at, first try | resolve a session cookie (a row with `retry` asks for a second pass) |
| `framework/api_key_resolve` | key digest, at | resolve an API key entrance |
| `framework/session_issue` | party, session id, credential version, expires at | issue a session (auth binding) |
| `framework/credential_floor` | party, floor | raise the credential version floor |
| `framework/session_revoke_party` | party, version | revoke a party's sessions below a version |
| `framework/session_revoke` | session id | revoke one session (auth binding) |
| `framework/session_onboard` | session id, party, subject id | bind a created subject to the session |
| `framework/session_subject_staff` | session id, party, kind, subject id | the `SwitchSubject` attached route |
| `framework/browser` | browser id, at | the `DeclareBrowser` attached route |
| `framework/audit` | seed, stage, service, party, outcome, at | one row per entrance stage |
| `framework/outbox_parent` | id, dedupe key, payload (json), event id, at, folded | outbox parent row of a write |
| `framework/outbox_child` | id, kind, payload (json), parent id, at | outbox child row (one queue message) |
| `framework/outbox_done` | event id | mark a consumed event done |
| `framework/outbox_get` | id | load a queued message |
| `framework/outbox_sent` | id | mark a swept message sent (not called since 0.11.6) |
| `framework/outbox_sweep` | kinds | list unsent messages to resend |
| `framework/outbox_claim` | id | claim one swept row before sending it (0.11.6; generated by default, see above) |

**Worker env** — `DATABASE_URL`, `COOKIE_DOMAIN`, `OUTBOX` (queue binding), `<ENTRY>_HOST` per entrance, the `key_binding` of `browser` (a Secret Store binding), the KEK bindings of `Sealed` properties, and optionally `ISOLATE_MARKER=1` (test header).
