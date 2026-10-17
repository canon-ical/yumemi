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

**One version (0.12, article 41).** The generator reads the `manifest.toml` of the app package and of every face it writes, and stops (exit 4) naming the package whose locked `yumemi` differs from the version that is running (`<dir>/manifest.toml: yumemi の lock <locked> が走っている生成器の版 <running> と違う`); run `gleam update yumemi` there. A package without a `manifest.toml` is not checked, and packages the generator does not read or write (another app's auth service, say) are outside the check.

A face's `priv/static/_yumemi/client.mjs` is bundled with the esbuild the face's lockfile installed (`<face>/node_modules/.bin/esbuild`). When it is missing the generator stops with exit 3 and names the path — add `esbuild` to the face's `devDependencies` and run `npm ci` in the face. It does not fall back to `npx`.

## Developing yumemi

```
npm ci        # the esbuild the generator tests bundle with
gleam test    # the runtime checks and the generator tests (fixtures in gen/fixtures)
```

`gen/fixtures` (sample apps) and `gen/scripts` (one-off verification scripts from earlier releases; the ones that ran the old `yumemi_gen` package were removed in 0.12) are not part of the Hex package.

To generate a fixture in place, run the generator from the root (`gleam run -m yumemi/gen -- gen/fixtures/article gen/fixtures/article`). The fixture faces have no `package.json`, so first link the root's esbuild into each face that has a client (`public` in `article`: `mkdir -p gen/fixtures/article/public/node_modules/.bin && ln -s "$PWD/node_modules/.bin/esbuild" gen/fixtures/article/public/node_modules/.bin/esbuild`); without it the generator stops with exit 3. When yumemi's `[dependencies]` change, run `gleam update yumemi` in each fixture face, or its client build cannot see the new packages.

## `yumemi/front` ── Elements and attributes (0.12)

A Block, a Layout's Block and the docs page are written with yumemi's own element tree; a ★ module imports `yumemi/front/el`, `yumemi/front/html`, `yumemi/front/attr` and `yumemi/front/css`, and never `lustre` or `sketch/lustre` (the generator stops on that import, exit 4, article 1; a face's `gleam.toml` listing `lustre` / `sketch_lustre` stops too, article 2). There is no exception: interactive Components are written with the same words (below). A `.gleam` file placed by hand under a face's `src/gen/` (one without the `//// GENERATED` first line) is read as ★ and checked the same way. A ★ module may not use `@external` (exit 4, article 4); JavaScript goes in a named escape (below).

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

- `el.Element` and `el.Attribute` are opaque and take no type parameter. `el.text` / `el.each` / `el.none` / `el.fragment`, the framework words (`el.opener` / `el.closer` / `el.badge` / `el.each_modal` / `el.img` / `el.notice` / `el.dialog` / `el.dialog_opener` / `el.dialog_closer` / `el.stylesheet`) and `el.to_string` (for tests) are public; the rest of `el` is `@internal` and a ★ calling it stops the generator (article 3).
- `html` has 53 tags a business CMS uses, the 8 a document needs (0.13.1: `caption`, `del`, `em`, `h5`, `h6`, `i`, `kbd`, `sup`) plus `svg` / `path`, each as `tag(class, attributes, children)` and `tag_(attributes, children)`, with sketch_lustre's names and argument order. There is no `style`, `script` or `link`.
- `attr` has typed attributes with lustre's names, `data(name, value)`, `aria(name, value)` and `role(attr.Status | ..)`. There is no free-name attribute, no `class` (a class is the tag's first argument, `css.class(styles)`), no `style` and no event.
- Rendering never fails a page: a `data` / `aria` name that is not `[a-z][a-z0-9-]*` drops that attribute (a literal one stops the generator, article 7); `href` / `src` / `action` are dropped unless the scheme is `http`, `https`, `mailto`, `tel` or none (a relative URL); the same attribute written twice keeps the last one (written twice literally in one list stops the generator, article 8); `</` and `<!--` inside the generated `<style>` become `<\/` and `<\!--`. Fragments leave no comment markers, and a `textarea` / `pre` whose text starts with a newline keeps it.
- `el.img(class, src, alt, attributes)` (0.12). `src` is an `el.Src`, made only by the generated `media.src(blob, media.W800)` (`src/gen/media.gleam`, from the app's media table) or `el.static_src("logo.png")` (a file under `priv/static/`: the path must be a string literal, exit 4, and the file must exist, exit 3; article 43). An `attr.src` in `attributes` does not override it.
- `attr.data("yumemi-…", ..)` renders nothing and a literal one stops the generator (article 7): `data-yumemi-*` attributes are the framework's marks (where a button sends, a Component's state, an escape).
- `el.dialog(key, class, attributes, children)` renders `<dialog id="yumemi-dialog-<key>">`; `el.dialog_opener(key, class, children)` / `el.dialog_closer(..)` render buttons with `command="show-modal"` / `command="close"` and `commandfor`. Where the browser has no invoker commands (`HTMLButtonElement.prototype.commandForElement` missing), the client calls `showModal()` / `close()` on their click. A dialog may sit inside an interactive Component's form and hold a send button (a confirmation step). The generated CSS keeps a closed dialog hidden (`dialog:not([open]) { display: none !important }`, also inside an `@layer`), so a Style's `display` on the dialog does not show it closed. Likewise an element with the `hidden` attribute stays hidden whatever `display` its Style gives it (0.14.2: `[hidden]:not([hidden=until-found i]) { display: none !important }`, also inside an `@layer`); `hidden="until-found"` is left to the browser, which hides it with `content-visibility` so find-in-page can open it.
- `el.notice(class)` is the place a Component's After message shows after a reload or a `GoTo` (put it in a Layout Block; article 16 stops when a Component declares a message and the Layout has none).

### The raw-CSS escape (0.12)

`shell.stylesheets` (below) and `el.stylesheet(el.static_sheet("fonts/mincho.css"))` in a Block load a `.css` file from the face's `priv/static/`. Both are an escape hatch that the generator checks and counts:

- the file must exist under `priv/static/` (exit 3, article 28) and the `static_sheet` path must be a string literal (exit 4, article 31) — a variable piped in or `static_sheet` passed as a function value is not one; `"a.css" |> el.static_sheet` is. At run time a path holding `//`, `\`, `:` or a `..` segment points nowhere (`/`);
- no selector may name generated output — `[data-yumemi-…]`, a generated class `.css-<8 hex>`, a `[class…]` selector whose value holds `css`, or an element whose name starts with `yumemi-` (exit 4, article 29). CSS escapes and spaces inside brackets are undone before the check, and at-rule preludes (`@scope (..)`) are checked too. An interactive Component's own tag (`like-button`) and its `:state()` are fine, and so is reading `var(--yumemi-theme-*)` in a declaration;
- no `@import` (exit 4, article 30);
- the rules are counted per face — each top-level block is one rule, an `@media` block is one, and a file read from two places counts once — in the face's escape line (below).

## `yumemi/front` ── Markdown (0.13.1)

`yumemi/front/markdown` reads Markdown held in the database at run time and draws it with yumemi's elements: a plain view-function Component a Block calls. A face can depend on nothing but yumemi and `el` takes no raw HTML, so the Markdown is read into a tree (`Block` / `Inline`) and built from `html` tags. HTML written in the Markdown stays text and is escaped; there is no raw-HTML path.

```gleam
import yumemi/front/css
import yumemi/front/el.{type Element}
import yumemi/front/html
import yumemi/front/markdown

fn look() -> markdown.Look {
  markdown.Look(
    ..markdown.bare(),
    paragraph: markdown.Part(css.class(style.para), []),
    code: markdown.Part(css.class([css.OverflowX(css.OverflowAuto), css.Spaces(css.Pre)]), []),
    link: markdown.Part(css.class(style.link), []),
  )
}

pub fn view(it: In) -> Element {
  html.article(css.class(style.page), [], [
    markdown.view(it.article.body, markdown.document(), look()),
  ])
}
```

- **What is read is chosen by `Options`.** Three are provided, and any field can be changed (`markdown.Options(..markdown.document(), tables: False)`):
  - `document()` — headings `#`–`######` (h1–h6), paragraphs (lines joined), fenced code with the language name, tables (`|` rows with a `|---|` separator line; `|` inside code and `\|` do not split), quotes (`>`, read as blocks), nested bullet (`-` `*` `+`) and numbered (`1.` `1)`) lists, rules (`---` `***` `___`); inside a line code (`` `x` ``, `<code>x</code>`), `**strong**`, `*emphasis*`, `[links](/relative/too)`, `<https://autolinks>`, `\` escapes and `&lt;` `&gt;` `&amp;` `&quot;` `&#n;`.
  - `post()` — what a user writes in a post: `#` and `##` are level 2, `###` is level 3, paragraphs keep their line breaks (`br`), blank lines are kept and counted (`Blanks(count)`, drawn as that many empty lines), `- ` / `* ` bullets and `1. ` numbers one line each (written at the start of the line), a line of exactly `---` (spaces around allowed) is a rule, and inside a line only `**strong**` and `http(s)` links. Anything else (tables, quotes, code, emphasis, nesting) stays text.
  - `outline()` — a terms-like document: front matter (`---` … `---`, read with `markdown.field(doc, "status")`), lines trimmed, `#`–`###` are levels 1–3, `- ` bullets and `1. ` numbers (the start is not kept), paragraph lines joined with nothing between them, no marks inside a line.
- **Links pass a fence or stay text.** `Links`: `WebLinks` takes only `http://` / `https://` URLs without spaces, `"`, `<` or `>`; `SafeLinks` takes what `attr.safe_url` takes (http, https, mailto, tel and relative URLs); `NoLinks` reads none. A `[text](url)` whose URL does not pass is left as text, so a `javascript:` link never becomes an `<a>`. A link's text may not hold `[` or `]`. `![alt](src)` is not read (no images).
- **The tree is public.** `markdown.parse(text, options)` gives a `Document(meta, blocks)`, `markdown.blocks` the blocks; an app that draws with its own Blocks walks `Heading` / `Paragraph(lines)` / `Code(lang, text)` / `Quote` / `Bullets(items)` / `Numbered(start, items)` / `Table(header, rows)` / `Rule` / `Blanks(count)` and `Plain` / `Strong` / `Emphasis` / `CodeSpan` / `Link(href, label)`. A list item is a list of blocks; a one-line item is one `Paragraph`. `markdown.render(blocks, look)` and `markdown.render_inlines(items, look)` draw a tree, `markdown.inline_text` and `markdown.plain(text, options)` give the text without marks (`plain` keeps the line count and order, drops rule lines and keeps a number's `1. `; for excerpts), `markdown.rule(line, options)` tells a rule line.
- **How it is drawn is chosen by `Look`.** Each kind of element takes a `Part(class, attributes)`; `bare()` gives none. `heading` is a function of the level, `code_frame` / `table_frame` wrap the `pre` / `table` in a `div` when `Some`, `link` carries e.g. `attr.rel("nofollow ugc noopener")`, and `spaces: KeepSpaces` keeps leading spaces and runs of two or more as U+00A0 (`CollapseSpaces` leaves the text as is). The heading tag follows the level (`h1`–`h6`); a numbered list that does not start at 1 puts the start on its first `li` as `value`; a code block's language goes to `data-lang` on the `pre`; header cells get `scope="col"`; emphasis is `em`; a list item whose first block is a paragraph has the paragraph's text directly in the `li`. There is no syntax highlighting.
- The code that reads and draws is the same in the Worker and in an interactive Component's client bundle. In node, a 29,000-character document (`gleam-for-php-users`) is read and drawn in about 48 ms.
- **Text from writers who are not trusted can be drawn on every request.** Reading takes time linear in the text: an opening mark that never closes (`[`, `` ` ``, `**`, `<code>`, `<http`) or a link whose URL fails the fence is not re-read up to the end of the line for every mark, and long runs of spaces inside a line do not slow it down. Quotes and list items nest at most 16 deep (`document()`; `post()` and `outline()` do not nest); a deeper `>` or list marker stays text. In node, 30,000 characters of such text (a line of 30,000 `[`, 7,500 code spans, 30,000 nested `>`, unclosed `<code>` / `<http`, a list nested 170 deep) are read and drawn with each of the three readings in at most 40 ms on the first call of a fresh process (2–15 ms once warm), with no stack overflow. A table whose output is ten times the text (one row of 15,000 cells) takes about 100 ms on a first call.

## `yumemi/front` ── Interactive Components (0.12)

An interactive Component is a `src/components/<name>.gleam` module with a few constants and a view that takes Args and returns elements. There is no `update`, no State, no Event and no lustre: the state lives in the form's controls and in the element's custom state (`:state()`), and the generated client runtime (`yumemi/front/interactive.mjs`) moves it.

```gleam
import gen/live/article_publish as publish
import gen/live/article_create as create
import gen/route
import gen/service
import gleam/option.{None, Some}
import yumemi/front/css
import yumemi/front/el.{type Element}
import yumemi/front/html
import yumemi/front/live

pub const calls: List(service.Service) = [service.ArticlePublish, service.ArticleCreate]

pub const after_send: List(#(service.Service, live.After(route.Route))) = [
  #(service.ArticlePublish,
    live.After(ok: live.GoTo(route.ArticleArgSlug, notice: Some("Published")), error: live.Stay)),
  #(service.ArticleCreate, live.After(ok: live.ReloadPage(notice: None), error: live.Stay)),
]

pub fn view(p: publish.Args, c: create.Args) -> Element {
  html.div_([], [
    html.input_([publish.bind(publish.Slug, p.slug)]),
    publish.send(css.class([]), [el.text("Publish")]),
    el.dialog_opener("copy", css.class([]), [el.text("Copy")]),
    el.dialog("copy", css.class([]), [], [
      html.input_([create.bind(create.Slug, c.slug)]),
      create.send(css.class([]), [el.text("Create")]),
    ]),
    publish.when(publish.Refused(publish.AlreadyPublished), [el.text("Already published")]),
    publish.when(publish.Succeeded, [el.text("Version "), publish.out(publish.OutVersion)]),
  ])
}
```

- **`calls`** lists one or more Services (constructor literals, no repeats; article 10). An attached upload route goes in the same list as `front.Entry(api.BlobCopy)` (the list's type is then `List(front.Target(service.Service, api.Attached))`); `pub const target` is gone.
- **`view`** takes each Service's `Args` in `calls` order, plus an optional last `with: With` (article 11). `With` is a record in the same module: display values the placing Block passes once at render time (labels, choices). It is not state, never reaches the browser as data, and may not hold a live type, an `el.Element`, an `el.Attribute` or a function (article 22) — nor through an unqualified import (`el.{type Element}`), a record of the same module held in a field (`List(Item)` with `Item(icon: el.Element)`) or a type alias (`pub type Icon = el.Element`).
- **`after_send`** has one `#(Service, live.After(ok:, error:))` per *write* Service in `calls` (missing: exit 3; for a read Service or twice: exit 4; article 12). `live.Then` is `Stay`, `ReloadPage(notice)` or `GoTo(route.<Page>, notice)`. `route` is the face's closed enum of Pages (`src/gen/route.gleam`). A `GoTo` path's holes are filled from the Service's Out fields of the same name (article 15); an `error:` `GoTo` must name a Page without holes, since a failure body is not an Out (exit 4, article 15). A `notice` shows once in the Layout's `el.notice`.
- **`reloads`** (optional): `live.Reloads(read: service.<Read>, on: [<read>.<Field>, ..])` calls the read Service again when one of those controls changes (article 17). If the read's Out has no `List`, the runtime calls it and fills its `out` spans (an earlier call is aborted). If it has one, the runtime moves to the same Page with the field in the query (`?<field>=…`), replacing the history entry, keeping the scroll and the focus; the placing Block renders the rows.
- **The generated live module** (`src/gen/live/<service>.gleam`) gives `Args`, `Field`, `Error`, `When` (`Idle`, `Waiting`, `Succeeded`, `Failed`, `Refused(Error)`; `Failed` shows for a failure the Component has no `Refused` branch for, so a refusal it branches on beside its `when(Failed, ..)` never also shows the generic failure branch, and one it does not branch on still shows `Failed`; a `Refused` branch nested inside the same Service's `when(Failed, ..)` is hidden with it, so it does not count — that refusal shows both texts, the generic one around the specific one; `Error` has the Service's `Error` constructors plus `DeclarationMissing` / `ConsentMissing` when its `requires` has `Declared` / `Consented` or `ConsentedFor` — the 403 `declaration_missing` / `consent_missing` — and `DeclarationMissing` for an attached route with `NeedsDeclared`), `Slot` (`Out<Field>` for each non-list Out field) and `bind(field, value)` (name `<service>.<field>`, plus `minlength` / `maxlength` / `required` / `pattern` from the value type's Spec; on a `textarea` with no children the value is rendered as its content, since a browser ignores a textarea's `value` attribute), `bind_check`, `bind_choice`, `bind_file` (a Blob field: the runtime uploads the chosen file to `/api/blobs` and puts its key in the Args), `when(state, children)` (a `<span>` with `display: contents`, so it may sit inside a `<p>`), `out(slot)` and `send(class, children)`.
- **Args are typed.** Each `Args` field has the Gleam type the Service's Args field has on the wire: `Bool`, `Int`, `Float`, `Option(..)` and `List(..)` as they are, and `String` for every other scalar (value types, ids, enums, dates — the back reads them as text). A Block writes initial values in that type — `create.Args(slug: it.slug, tags: ["news"], note: None)`, never `tags: "[\"news\"]"` or `"true"` — and the generated `args_json` writes the JSON. A Service whose Args field is a record, a tuple, a `Dict` or a `List` of non-scalars cannot be in `calls` (exit 4, article 11).
- **No chaining on the client.** One send button calls one Service; the runtime drops a submit without a send button and ignores Enter in a control of another Service. A Component may not import the live module of a Service outside `calls` (article 19), every Service in `calls` must be sendable (a write needs a `send`, a read a `send` or `reloads`; a list read may not have a `send`; article 20), and an `out` may not sit inside `textarea` / `select` / `option` (article 21; the generator follows pipes, `let` variables and functions of the same module, and the runtime never writes a read's result into an `out` inside those controls). Combine Services on the server, in one Service.
- **Placing it.** A Block calls the generated `src/gen/interactive.gleam`: `interactive.article_manage(publish.Args(slug: it.slug), create.Args(..))`. The Component renders on the server inside its tag (`<article-manage data-yumemi-island data-yumemi-args="…"><form method="dialog"><fieldset>…`), in light DOM, with the same generated class names and page `<style>` as a Block; JavaScript adds no style. There is no send without JavaScript: the form's `method="dialog"` makes a submit the runtime does not take (no JavaScript, still loading, or a script error) send nothing — a form without a method would put the body in the URL — and inside a dialog it only closes the dialog. A ★ form (`html.form`, e.g. a `GET` pager) keeps the method it is written with. A Component may not sit inside a ★ form (exit 4, article 44): HTML drops a form inside a form, so the Component's controls would belong to the ★ form and be sent with its method — through a `GET` form, in the URL. The generator follows pipes, `let` variables and functions, also those of other modules that place a Component; put the Component beside the form. The tag is the module name with `_` → `-` and must be a custom-element name not starting with `yumemi-` (that prefix belongs to the runtime's elements such as `yumemi-escape`; article 18); a Component may not place another one.
- **State.** The runtime sets `waiting` and `sent-<service>` while a call runs (the fieldset is disabled and `aria-busy="true"` for a send, not for a single-value reload), then `ok` or `error` (+ `refused-<code>` for a code the live module's `Error` names, and `failed` unless the Component holds a `when` branch for that refusal outside the Service's `failed` branch). Where `ElementInternals.states` is missing it writes the same names to `data-yumemi-state`; the generated CSS hides `when` branches both ways (`@supports selector(:state(x))` and its negation). A Block's or Component's Style can react with `css.State(css.Waiting | css.Succeeded | css.Failed, ..)`; `css.Failed` follows `error`, so unlike the live module's `Failed` it also matches a refusal the Component branches on.
- `pub fn app` in a Component stops the generator (exit 4, article 9). The 0.11 shape (`app()`, `view(it: State)`, `after_send: live.After` with two values, `reloads: List(#(Field, Service))`) no longer compiles.

## `yumemi/front` ── Named escapes (0.12)

JavaScript a page needs and yumemi has no word for goes in `src/escapes/<name>.mjs` (`[a-z][a-z0-9_]*`, article 6) and nowhere else under `src/` (exit 4, article 5). The file exports `mount(element)` (exit 3 when it does not), which may return a function to call when the element leaves.

```js
// src/escapes/chat_socket.mjs
export function mount(element) {
  const socket = new WebSocket(element.dataset.url);
  return () => socket.close();
}
```

The generator writes `src/gen/escapes.gleam` with one function per file, `escapes.chat_socket(attributes, fallback)`, which renders `<yumemi-escape name="chat_socket" …>fallback</yumemi-escape>`; the fallback shows without JavaScript. The client bundles the files and mounts each element when it connects (also after client navigation) and unmounts it when it leaves. An escape may sit inside an interactive Component and write its controls.

**The escape line.** Per face the generator prints one warning (exit 0, also in `_diagnostics.txt`) counting every escape hatch: `[exit 0 警告] <face>: 逃げ道 ── escape <kinds> 種 <calls> か所(うち interactive Component の中 <n>)、生の CSS <files> file <rules> 規則、数える口の送り先 ToService <n>`.

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
- The registration does nothing where `navigator.serviceWorker` is missing, and a failed registration is swallowed (the page keeps working). Client navigation does not reload `client.mjs`, so it registers once per page load. A face without interactive Components or escapes gets a `client.mjs` that only registers the worker (and the page loads it); a face with none of them gets no `client.mjs`, as before.
- Client navigation keeps the `<head>` elements the next page also has and swaps the rest, so each element stays exactly once after a navigation.
- A constant that is present but is not a non-empty `String` constant (another type, or `""`) stops the generator like a missing `title`: exit 3, `<face>/src/shell.gleam: <name> は空でない String の定数で書く`. For `stylesheets` the same holds when it is not a list literal of non-empty strings: `<face>/src/shell.gleam: stylesheets は空でない String の List の定数で書く`.

## `yumemi/front` ── Client navigation (0.11.4, 0.11.15, 0.12)

The generated client calls `yumemi/front/navigate.mjs`'s `start({routes, csp})`. `routes` lists every Page route of the face; `csp` maps each route of a gate `frame_src` Page to the `content-security-policy` value the gate sends with it (`frame-src https://<host> ..` from the entry's `frame_src` hosts). A face without such Pages gets no `csp` key, exactly as in 0.11.14.

Since 0.12 the browser's [Navigation API](https://developer.mozilla.org/en-US/docs/Web/API/Navigation_API) does the browser's part: it reports the navigation (`navigation`'s `navigate` event), keeps history, restores scroll, resets focus, aborts a superseded navigation and handles fragments. `navigate.mjs` takes a navigation with `event.intercept()` and does the rest: the fetch, the swap check, the head diff, the stylesheet wait, the body swap, and the pageview mark. Interactive Components and escapes in the new body start by themselves: their custom elements are defined once, and each connects when the body is inserted (0.12 has no `boot`).

- **Which navigations.** A push or replace the user started (a link, a GET form) and a back / forward within the document, from a routed Page to a routed Page, whose destination has the same CSP as the Page that loaded the current document (both none, or the same value). A CSP header only takes effect on a page load, so a link to a Page with another CSP — or from a Page without one to a Page with one — is a page load, and the destination's policy holds. The browser handles everything else as it would without `navigate.mjs`: modified clicks and `target` (another tab), `download`, POST forms, other origins, a fragment within the page, navigations a script starts (`location.assign`), a plain `location.reload()`, and links to unrouted paths. A back / forward within the document to an unrouted entry is taken and reloaded as a page load, so the URL and the page never disagree.
- **Without the Navigation API** (Baseline 2026: Chrome 102, Firefox 147, Safari 26.2) `start` does nothing: every link is a page load, and so is reload after a write.
- **Which responses.** One fetch with `x-yumemi-navigate: 1` (the gate, the adult declaration and the session go through the server as before), aborted with the navigation's `signal`. It falls back to a page load of the destination on a redirect (a gate's 302, e.g. to `/enter`), a non-200 (except a face's failure page, below), a non-HTML body, a `content-security-policy` header that differs from the route table's value for that Page (or is present where the table has none, or missing where it has one), or a page with scripts other than the client. The URL has already changed by then, so the fallback is `location.replace` (no extra history entry); the server sees the same GET twice.
- **The head.** Elements whose `outerHTML` is the same in the current and the next `<head>` stay where they are (a stylesheet is not re-requested); the others are removed or inserted at the next page's positions, so the order follows the next page. The client script stays.
- **Stylesheets load before the body changes.** A stylesheet new to `<head>`, and a copy (in `<head>`, marked `data-yumemi-hold`) of each stylesheet that only the next page's `<body>` links (an article's font CSS, say), is inserted with `media="not all"` and awaited (load or error, at most 3 seconds); then its `media` is restored, the old head elements leave and the body is swapped. A copy is removed once the body's own `<link>` has loaded. The old page stays on screen meanwhile, so no unstyled page shows; the swap waits for those downloads.
- **Scroll and focus** follow `intercept()`'s defaults once the new body is in: a push goes to the fragment or the top, back / forward return to the position the entry was left at; focus moves to the `autofocus` element or `<body>`. Reload after a write is taken with `scroll: "manual"` and keeps the current position (the reload default would go back to the top, since the entry's position is only saved when leaving it).
- **A same-document change during a fetch.** If a fragment link or `history.pushState` / `replaceState` aborts the fetch of the next page, and no newer navigation was taken, the current URL is reloaded (`location.reload()`), so the URL and the page never disagree.
- **History a script pushed.** Back / forward to an entry a script pushed on the current page (an escape's `history.pushState`) is left to the browser: the page is not refetched, a Component keeps its state, and no pageview is counted. 0.12's interactive Component runtime itself never pushes history (a list `reloads` replaces the entry).
- **Runtime navigations.** A Component's `GoTo` and a list `reloads` call `navigate.go(href, {replace, keep, count})`, which `navigate.mjs` takes like a user's push (a list `reloads` replaces the entry, keeps the scroll and puts focus back on the same control).
- **A list `reloads` is not a pageview.** It refetches the page because a field changed, not because the user navigated, so it passes `count: false`: the navigation's `info` carries `count: false` and the pageview sender skips it (and, if it falls back to a page load, skips that load once, by a mark kept for 10 seconds under the session key `yumemi:uncounted`). A `GoTo` is counted as `spa`.
- **Reload after a write.** A Component's After `ReloadPage` calls `navigate.reload()`: on a routed Page it calls `navigation.reload()` with a mark and takes that reload, refetching the current URL the same way (no history entry, scroll kept); otherwise, or without the Navigation API, it reloads the page.
- **Pageviews: the mark only.** For the navigation fetch the gate puts `<meta name="yumemi-pageview">` in `<head>`. `navigate.mjs` does not post pageviews (0.11.4 to 0.11.15 did); it replaces the mark on every swap, so when `navigation` fires `navigatesuccess` the document holds the next page's mark and never the previous page's. A pageview sender reads the mark there and the kind from `navigation.transition.navigationType` (`push`, `traverse`, `reload`). `navigatesuccess` also fires for a same-document navigation `navigate.mjs` does not take (a fragment within the page, `history.pushState` / `replaceState`); `navigation.transition` is then `null` and the current page's mark is still in the document, so a sender counts only when `navigation.transition` is not `null`. `start` no longer takes `pageview`.
- **No `yumemi-navigated` event.** Listen to `navigation`'s `navigatesuccess` instead (0.11.4 to 0.11.15 dispatched `yumemi-navigated` on `document`).

## `yumemi/front` ── The failure page (0.14.3)

A face may declare one **failure page**: a plain `Page` in `<face>/src/failure.gleam`.

```gleam
pub const page: Page(service.Service, blocks.Block) = Page(
  of: None,
  layout: layout.main,          // the face's Layout: frames the failures after the gate (not the gate's own)
  theme: None,
  vars: [Var("failure", Failure)],
  sp: Frame(areas: [..], placements: [Fixed(area: "page", block: blocks.FailureNote, cell: Flow)], ..),
  pc: None,
  tablet: None,
)
```

Then the generated shell and gate answer a request that wants a page, and fails, with that page, **keeping the original status code**. A face without `src/failure.gleam` generates exactly what 0.14.2 generated.

- **`Failure`** is a new variable source, allowed only on the failure page. Its value is a String: `"forbidden"` (401, 403), `"not_found"` (404, 405, 410 and any other 4xx) or `"unavailable"` (5xx and exceptions). One Block reads it and words the page; the status stays on the response.
- **What the failure page may hold** (article 45; the generator stops with exit 4, or exit 3 when `src/failure.gleam` has no `pub const page: Page(..)`): `of: None`; `Fixed` placements only (no `Widget`, no `Live`), whose Blocks read no Service (`In = Nil`); Page vars `Failure` and `CurrentRoute` only (`CurrentRoute` is `""` there). `Origin` and `AuthOrigin` come from the Layout, as on any Page. `Failure` anywhere else (a Page, the Layout) stops the generator. On a face with a failure page the Layout's `Fixed` Blocks may not read a Service either (put a read in a `Widget`). So the page can be drawn from any URL's failure without the API.
- **The gate's failures have no frame.** A failure the gate returns (the session read's 503 / 404 / 403, `Admitted`, `Deny`, and an unmatched path stopped by an `Every` rule) is drawn without the Layout: only the failure page's own `Fixed` Blocks (wrapped in `<div data-yumemi-failure="bare">`), and the Layout's Widgets are not read. The gate has not yet let the requester in, so they do not see the face's bars and navigation. Failures after the gate (the shell's reads, exceptions, an unmatched path for someone the gate let through) keep the Layout.
- **The Layout's Widgets are read** (failures after the gate), and a Widget whose read fails (any non-2xx, an exception, a body the decoder refuses) is simply not drawn: when the API is down the page still shows, with the Layout's static parts and the page's own content.
- **Which requests get the page.** `GET` or `HEAD`, without `x-yumemi-block`, with `sec-fetch-dest: document`, or `text/html` in `accept`, or `x-yumemi-navigate` (the client navigation's fetch). Every other request (the fragment answer, assets, an island's or a test's `fetch`, a `POST`) gets the plain text as before (`forbidden`, `not found`, `unavailable`, a gate `Deny`'s body).
- **Which failures.** The shell's: the root read's 403 / 404 / other 4xx / 5xx, a session read's 5xx, a `Session` variable without a subject (401), a path no Page matches (404). The gate's: `Admitted` and unknown checks (403), the session read's 404 / 5xx / other, and `Deny(status, body)` (the page with `Deny`'s status; the body stays for requests that do not want a page). Redirects stay redirects.
- **Exceptions.** On a face with a failure page, `renderPage`, `renderBlock` and the reads' decoders run inside a `try`: an exception is logged (`yumemi shell: render error`) and becomes a 500 `unavailable` (the failure page for a page request, the plain text for the fragment answer) instead of the Worker's exception page.
- **No loops.** If the failure page itself cannot be drawn (an `Origin` env var is missing, the render throws), the plain text goes out. The failure page is never wrapped in another failure page, and a missing env var's name never reaches HTML.
- **Paths no Page matches meet the gate.** On a face with a failure page, a page request for an unmatched path goes through the checks of every gate `Rule` whose `pages` include `Every` (their `except`, `Exact` and `Prefix` are about routes and are not looked at). So a face that admits only its own users sends everyone else to sign-in (or its own refusal) rather than showing them its Layout around a 404. Faces without a failure page are not changed: an unmatched path still skips the gate.
- **The response.** `content-type: text/html`, `cache-control: no-store`, `x-yumemi-failure: <status>`, and the route's `content-security-policy` when the URL matches a Page with one (also when the gate refused). For a path no Page matches, the `content-security-policy` of the `Csp` declarations whose `pages` include `Every`. The pageview mark is not added (only 200s carry it).
- **Client navigation.** `navigate.mjs` swaps in an HTML response that carries `x-yumemi-failure` as it would a 200 (same CSP check, same `swappable` check), so a link to a missing page shows the failure page in place (with the Layout's bars and navigation after the gate, without them for the gate's refusal) with one request, and back / forward work as for any page. Faces without a failure page never send the header.
- **For the face's own entry.** The generated `src/gen/shell.mjs` exports `failure(request, env, status)`, which returns the failure page for a page request and the plain text otherwise; an entry that answers some paths itself can use it instead of its own plain text.
- **Generated output.** A face with a failure page gets `src/gen/load/failure.gleam` (no fragment functions), a `failureSpec` and the failure runtime in `src/gen/shell.mjs`, the gate's failure path in `src/gen/gate.mjs` (`serve(dispatch, failure)`, `plain`, `isPlain`, `wantsPage`, `cspUnmatched`), `render_bare` in the failure loader, and the page's grid in `style.css`. The route table, the gate's tables and the fragment answer are unchanged.

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

`yumemi/front/css`'s `Style` is the typed vocabulary a Page / Area / component carries; `yumemi/front/sketch_css` maps it to CSS (sketch classes; from 0.12 a class name is a hash of the rendered CSS, so the same Style gets the same name in node, the Worker and a minified bundle, and an interactive Component's Style lands in the page's `<style>` like a Block's). `css.class(styles)` makes the `Class` a tag takes. Every word also works inside `State(Hover / Focus / FocusVisible / HoverCapable / Disabled / Current / Waiting / Succeeded / Failed / ThemeImage, ..)` and `Responsive(SP / PC / Tablet, ..)`.

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
| `Border(edge: AllEdges / TopEdge / BottomEdge / LeftEdge / RightEdge, width, style: Solid / Dashed / Dotted, color)` | `border` / `border-top` (0.12) / `border-bottom` (e.g. the 2px tab underline), and (0.13.1) `LeftEdge` / `RightEdge` — `border-left` / `border-right` (a heading's side band, a quote's rule) |
| `TextAlign(align: TextStart / TextCenter / TextEnd)` | (0.12) `text-align: start / center / end` |
| `Center` | (0.13.1) `margin-left: auto; margin-right: auto` — centres a box in its parent; pair it with `Space(MaxWidth, ..)` for a reading column. The vertical margins are left alone |
| `OverflowX(overflow: OverflowAuto / OverflowHidden / OverflowVisible / OverflowScroll)` | (0.13.1) `overflow-x` — `OverflowAuto` lets a wide table or code block scroll sideways inside the text column |
| `Spaces(white_space: SpaceNormal / Pre / PreWrap / PreLine / NoWrap)` | (0.13.1) `white-space` |
| `Slant(slant: Upright / Italic)` | (0.13.1) `font-style: normal` / `italic` |
| `Outline(width, offset, color)` | `outline-style: solid` / `outline-width` / `outline-offset` / `outline-color` — the focus ring, inside `State(FocusVisible, ..)` (0.11.14; `State(Focus, ..)` also keeps it after a tap) |
| `Space(property:, value:)` | `margin` / `padding` / `gap` / `width` / `height` / `border-radius`, and (0.11.7) `min-width` / `min-height` / `max-width` |
| `Text(family:, size:, weight:, line_height:)` | `font-family` (`System` / `SansSerif` / `Serif` / `Monospace`, or `Named("var(--ma-font-ui)")` / `Named("\"Noto Sans JP\", sans-serif")`; each comma-separated `Named` item must be `var(--<name>)`, a quoted family name or bare words of `[A-Za-z0-9_-]`, else the value is `unset`), `font-size`, `font-weight` (`Normal` 400 / `Medium` 500 / `SemiBold` 600 / `Bold` 700), `line-height` |
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

The back-end runtime (`yumemi/server/*.mjs`) is JavaScript that the generated `src/gen/*.mjs` imports. It knows no application names: route names, cookie names, key bindings, declaration and consent kinds and the party a queue consumer reads its borrowed root as come from the app's `src/server.gleam` (`attached_roles`, `browser`, `consents`, `hooks`, `roots`' `QueueParty`). The generated face gate (`<face>/src/gen/gate.mjs`, declared in `<face>/src/gate.gleam` with `yumemi/gate`) reads the session through the `ReadSession` attached route. Gleam packages cannot declare npm dependencies, so the app supplies the following itself.

Generated live modules (0.11.2) send Args by their declared type: `Bool` as a JSON boolean (the live field's `"true"` / `"false"`), `Int` / `Float` as numbers. On a `GET` route the Args that are not path holes go on the query string (an empty `Option` is left out), and the runtime reads `bool` (`true` / `false`) and `float` spellings from the query of `GET` / `HEAD` requests. `POST` / `PUT` / `DELETE` bodies are read as JSON as before.

A live field for a `List(X)` Arg (X a scalar, value type, id or enum) holds a JSON array of strings (`["a","b"]`, an empty field is `[]`); each item is sent by X's rule. A field for a record, tuple, `Dict` or a `List` of those holds the JSON body itself (for example `{"background":"#112233"}`), which is sent as is and read by the back-end decoder. A field that does not parse is sent as a string, and the back end answers `invalid_argument`. Sum types with several constructors are sent as strings.

A Service whose logic runs `step.commit` and continues after it (and is not a queue consumer that only uses the commit as a boundary) ends in `Accepted` over HTTP: the runtime answers 202 with a one-field body (`{"<root>": id}`, a `respond` hook may rename the field). The generated live for such a Service (0.11.3) holds `Reply` instead of the Service's `Out`: `Accepted(id)` for the 202 body and `Replied(out)` for a 200 that ends before the commit. Both arrive as `Done(Ok(_))` and go on to `after_send` (for example `ReloadPage`). Lives of other Services are unchanged.

0.11.4 adds, without changing the existing public types:

- **Reads time out and retry once.** `driver.mjs` cuts a read-only statement (one `SELECT` / `WITH` / `VALUES` / `TABLE` with no write keyword — `INTO` and row locks count as writes — and no call to a function outside the built-in allow list, read after one pass that strips strings, quoted identifiers and comments; see `yumemi/server/read_retry.mjs`) after `DATABASE_READ_TIMEOUT_MS` (default 10000) and retries it once when the failure is outside the database (timeout, fetch failure, HTTP 5xx; not an SQLSTATE). Writes and transactions are never retried and get no timeout. Every failure outside the database, read or write, is logged as one JSON line (`{"yumemi":"driver.failed",kind,key,attempt,ms,code,status,name,body}`, `kind` is `read` / `write` / `transaction`) with the response body.
- **Attached routes with a framework role that reads a body** send it: the live for a `SwitchSubject` route has `Args(kind, id)` and sends `{kind, id}`. Other attached lives are unchanged (no Args, `null` body).
- **The `BlobCopy` live copies a URL.** Besides the file upload (`Send`), `copy_from(state, url)` sends `{from: url}` to the same route and reads `{key}` into `Done(Ok(key))`. (0.12: `blob_copy.Args(file, from)` — the runtime uploads the chosen file, or sends `{from}` when no file is chosen, and puts `key` in `OutKey`.)
- **Split records decode.** A record Property stored with `Split` is rebuilt from its columns in `src/gen/codec.mjs`.
- **Islands render sketch classes.** The generated client registers each island through `yumemi/front/island_style.mjs`'s `styled(app)`: the island gets its own sketch stylesheet while its view runs, and the CSS goes into a `<style>` inside the island (only when the island uses classes and does not render its own stylesheet). (0.12 removes this: a Component renders in light DOM with the page's `<style>`, see "Interactive Components".)
- **Client navigation between Pages.** The generated client calls `yumemi/front/navigate.mjs`'s `start({routes, boot, pageview})`. A plain left click on a same-origin link, from a Page to a Page that are both in the face's route table (minus the gate's `frame_src` Pages), fetches the next page with one request (the gate, the browser's declarations and the session go through the server as before), swaps `<head>` and `<body>`, re-runs the island registrations and pushes history; back / forward do the same. A redirect, a non-200, a `content-security-policy` header, a page with scripts other than the client, an already-registered given island, a modified click, `target` or `download` fall back to a page load. (0.12 replaces this with the Navigation API and drops `boot`, see "Client navigation".)
- **Pageviews count once per navigation.** The navigation fetch carries `x-yumemi-navigate: 1`; for it the gate puts `<meta name="yumemi-pageview">` in `<head>` instead of the pageview script (same conditions as the script, 200 HTML, a `pageview` Page) and adds `vary: x-yumemi-navigate`. The client posts the pageview (`kind` `spa`) only after it swapped that page in; a fallback to a page load gets the script as before. (0.12 replaces this: see "The gate and the CMS features" below.)
- **Reload after a write stays in the page.** An island's `yumemi-done` calls `navigate.reload()`: on a routed Page it refetches the current URL the same way (no history entry, scroll kept, pageview `kind` `reload`); otherwise it reloads the page. (0.12: a Component's After `ReloadPage`, see "Interactive Components".)

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

0.12.2 fixes five holes that an app shaped unlike our in-house service fell into (an entrance named apart from its Host variant, no queue kind, no subject Entity, no hand-written FFI, a page size chosen by the caller, an Entity whose id the app does not make), without changing the public types:

- **The entrance host is looked up by the entrance's name.** The generated `hosts` table maps each entrance name to its `<ENTRY>_HOST` variable, and the runtime now reads it by name, so `Http(name: "api", hosts: [ApiHost], ..)` answers on `API_HOST` (0.12.1 looked it up by the variant's name, `api_host`, and answered 404 to every request). An entrance whose `hosts` list is empty is reached on no host and is left out of the allowed Origins, as before.
- **`src/gen/verb.gleam` takes `stage` from the generated `src/gen/operations_ffi.mjs`** next to it. 0.12.1 pointed at `src/operations_ffi.mjs`, which only an app with a hand-written bridge had, so the Worker bundle stopped.
- **An app with no queue kind gets a `src/gen/queue_runtime.mjs`** (`sweep` resolves to 0 without reading anything, `consume` does nothing), because `shell.mjs` and `cron_runtime.mjs` import it; it imports neither the outbox runtime nor its SQL. The file of an app with queue kinds is unchanged. **`src/gen/runtime.mjs` imports `./subject.mjs` only when a subject Entity exists** (the only case `src/gen/subject.gleam` is written).
- **A page whose size is a hole (`Paged(size: Param(..), ..)`) is cut at the size of the request**, the value bound to the SQL's `LIMIT $n + 1` (the read's keyset carries `sizeArg`, the hole's place among the read's args). 0.12.1 cut every such page at 20, so a request for any other size got size + 1 items and no `next`. A constant size (`Paged(size: Num(n), ..)`) is cut at `n` as before. A size below 1 is answered 400 `invalid_argument` with `field` set to the hole's name (`sizeField` in the keyset, `limit` for `Param(Limit)`) before any SQL runs. There is no upper bound: the app caps the size itself.
- **`auto_key`: the runtime makes the key.** An Entity module may declare `pub const auto_key: List(String) = ["id"]`, naming its key Property, when the app does not make the key itself. The Property is left out of the Entity's `Draft` (the create Service passes no id), and the create verb's `INSERT` still writes the key column: the runtime fills it with a UUID derived from the request's seed (as it fills the key column of every created Entity), and the `Created` value the verb returns carries that key. 0.12.1 left the column to the database's `DEFAULT`, but the `Created` value is built before the commit, so every create answered 400 `invalid_argument` on the key and wrote nothing. The key must be a single Property (not part of a composite key) whose value type is `Uuid` in `src/types.gleam` (`pub const note_id: Spec = Uuid`); any other type (a serial number, a text) or a composite key stops the generator with exit 4. `CreateMany` (`verbs.CreateMany`) of an `auto_key` Entity still leaves the key column out and needs a database `DEFAULT` (for example `DEFAULT gen_random_uuid()`). An Entity without `auto_key` is unchanged: its key stays in the `Draft` and the create verb's SQL and runtime table are byte-identical.

0.13.0 adds idempotency keys for writes and a switch for the SQL endpoint. **It needs a new table in the app's database** (`framework.idempotency`, below), so an app moves from a 0.12 lock to 0.13 together with that DDL. The public Gleam types are unchanged and ★ sources need no edits; regenerating writes the new SQL, the DDL file and the purge into `shell.mjs`.

- **A retried write lands once.** A request to a write Service (effect `Write`, run by the runtime; not a `service_<name>` port, not an attached route) that carries an `Idempotency-Key` header is recorded in `framework.idempotency` under (party, key): the response's status, content type and body, written by `framework/idempotency_record` as the **first statement of the write's own transaction** (the business statements, the outbox and the audit rows follow in the same transaction, so the record and the write commit or roll back together). A second request with the same key and the same body gets the recorded response (with `idempotency-replayed: true`) and runs nothing; the same key with another body is answered 409 `{"code":"idempotency_conflict"}`. "The same body" is compared through `request_hash`, an HMAC-SHA256 under the Worker's `IDEMPOTENCY_HASH_KEY` of the Service name and the request's fields (query, JSON body and path holes, keys sorted), stored as `h1:` and 64 hex digits (0.13.2; 0.13.0–0.13.1 stored the plain SHA-256, which anyone who reads the table can reverse for a field with few possible values, such as a phone number — see below). A second request that arrives while the first is still running passes the first look-up, and its transaction then fails on the unique (party, key) and rolls back whole; the runtime reads the record again and answers the first one's response. Any failure of a keyed write (a business refusal without a write, a lost database response after `COMMIT`) also looks the record up once more before answering, so a write that did commit is answered with its response.
- **Who owns a record:** the session's or the API key's party; without one, the signed browser mark (`browser:<id>`); without either, one shared `anonymous` owner. A key is looked up only under its owner, so another party that sends the same key gets its own write and never sees someone else's recorded response. Only the response that was sent is stored.
- **What is recorded:** a write that commits (`step.done` after staged verbs, `step.commit`'s 202) and a refusal that writes its verb (`step.reject`, recorded in the refusal's own transaction). A business failure that wrote nothing (`step.fail`, a guard) is not recorded: retrying it runs the Service again. A field the database fills by `RETURNING` is not known when the record is staged. For a generated create of an ordered Entity the record's body carries a mark where `order` goes, and the generated `verb/create_<entity>_idempotency_order` (after the create, in the same transaction) replaces the mark with the created row's `order`, so the record matches the answer at commit and a retry after a response lost past the commit answers the database's `order` (0.13 r2; the mark is used only when the response shows the value as is — an `api_encode` or `respond` hook that reshapes it keeps the repair below). A ★ `returned` (a hand-written verb that copies `RETURNING` onto the value) is applied by the request that ran it: the runtime repairs the record with `framework/idempotency_repair` right after the transaction when the final response differs, and if that response is lost a replay answers the ★ fields as staged while the row itself is correct.
- **No key, no change.** A request without the header (older clients, hand-written calls, cron, the outbox consumer) behaves exactly as in 0.12.2 and never touches the table. A key that is not 1–255 printable ASCII characters is answered 400 `invalid_argument` with `field` `idempotency_key`. Read Services ignore the header.
- **The client keeps the key until it has an answer.** A Component's write send (not a read, not `GET`, not an upload) makes a UUID for the Args it sends and puts it in `Idempotency-Key`. When the answer is unknown — a 5xx (the database's 503 included) or a network failure — the key and the form's input are kept and the error After (`ReloadPage`, `GoTo`) is **not** followed, so sending the same input again reuses the key. Any 2xx or 4xx drops the key; changed Args get a new key. A file field of a write send is uploaded once per chosen File: the blob key is kept with the key, so the retry sends the same Args under the same key instead of uploading again (an upload that answers a new key on every call would change the Args). Choosing another File uploads it and gets a new key; once there is an answer the kept blob keys are dropped with the key.
- **Old rows are purged by the cron.** The generated `shell.mjs` runs `purgeIdempotency` (`yumemi/server/cron.mjs`) on every scheduled event, whatever the expression: it deletes rows older than `IDEMPOTENCY_RETENTION_HOURS` (Worker env, a positive number of hours, default 24) with `framework/idempotency_sweep`. A retry after that window is a new write. The Worker needs at least one cron trigger for the purge to run.
- **The DDL is generated, not applied.** Every app with `src/server.gleam` gets `db/framework/idempotency.sql`: the table `framework.idempotency (party text, key text, request_hash text, result jsonb, created_at timestamptz)` with the primary key `idempotency_pkey (party, key)` and the index `idempotency_created_at (created_at)`. Applying it is the app's DDL step. Until it is applied, a keyed write fails (503 `unavailable`) and requests without a key are unaffected.
- **The SQL endpoint comes from the env.** `driver.mjs` sets `neonConfig.fetchEndpoint` to `DLEAM_SQL_ENDPOINT` (a full URL such as `https://dleam.example/sql`) when the Worker env has it, and leaves the driver's own endpoint (derived from `DATABASE_URL`'s host) when it does not; removing the variable goes back. It is set in `database(env)`, so every database handle of the app's generated Worker (fetch, queue, cron, `AppSystem`) uses it. A Worker that calls `neon()` itself instead of `database(env)` calls `useSqlEndpoint(env)` (exported by `driver.mjs`) before `neon()`.
- The generator adds default `framework/idempotency_find`, `_record`, `_repair` and `_sweep` statements to `src/gen/sql.mjs`; an app's own `db/queries/framework/<name>.sql` wins (to change the purge condition, for example).

0.13.1 adds the runtime Markdown Component, the 8 document tags and the document Style words (all above), and closes three holes a document site fell into. Public types only gain variants and modules; an app that does not hit the holes gets byte-identical generated output:

- **A face no longer needs the back's static materials.** `src/external_hosts.mjs` and `<repo root>/docs/api-v1.md` are each optional: when one is missing its copy (`src/gen/external.gleam`, `src/gen/doc/api_v1.gleam`) is not written to the faces, instead of stopping with exit 3. A file that is there and cannot be read, or whose `EXTERNAL_HOSTS` has another shape, still stops. `gen/doc/api_v1.gleam` names the face's `style.body`, `style.ink` and `style.heading`; for a face whose `src/style.gleam` does not define all three as `pub`, it is written with no class (`css.class([])`). An app with both files and those names gets byte-identical output.
- **A `Paged` list ordered by an integer, boolean, floating or text column reads.** The keyset's first placeholder (`$n IS NULL`) of a list ordered in one direction gets the column's type (`::integer`, `::bigint`, `::boolean`, `::double precision`, `::text`), as the uuid / time ones already did; without it PostgreSQL could not determine the placeholder's type (the driver sends untyped placeholders and `$n IS NULL` says nothing about it) and every page answered 503. Lists ordered by a uuid or time column keep their SQL, and the key's placeholder keeps the cast it had.
- **An internal failure is logged before it becomes `503 unavailable`.** When a request's failure is folded into `{"code":"unavailable"}` (not a business failure, not a connector failure, not answered by the app's `db_error` hook), `console.error` gets one JSON line `{"yumemi":"request.unavailable","service":…,"code":<SQLSTATE>,"constraint":…,"table":…,"column":…,"name":…,"message":…}`: a unique violation names its constraint (`"code":"23505","constraint":"note_title_key"`). The `detail` (which holds the key's value) is not logged, and `message` is logged only for SQLSTATE classes whose text holds no value (08, 23, 25, 40, 42, 53, 54, 57); it is `null` for class 22 (`invalid input syntax for type uuid: "…"` quotes the input) and for JavaScript exceptions (a `JSON.parse` error quotes the input). The response is still 503 `unavailable`.

0.13.2 keys the idempotency records' `request_hash`. **An app that upgrades puts the secret in before it deploys**: without it every write that carries an `Idempotency-Key` is answered 503 `unavailable`. There is no DDL change (`request_hash text` as before), the public Gleam types and ★ sources are unchanged, and the generated output is byte-identical.

- **The hash is an HMAC under a Worker secret.** `request_hash` is `h1:` + the hex HMAC-SHA256, keyed by the Worker env `IDEMPOTENCY_HASH_KEY`, of the Service name and the canonical fields. The key is a Secret Store binding (its `.get()` returns the text) or a plain Worker secret (`wrangler secret put IDEMPOTENCY_HASH_KEY`); like `IDEMPOTENCY_RETENTION_HOURS` the app does not declare the name. It must be at least 32 characters (make one with `openssl rand -hex 32`). The key's value and the HMAC's input are never logged, answered or recorded; replay and 409 behave as in 0.13.1.
- **No key, no keyed write.** When `IDEMPOTENCY_HASH_KEY` is missing, empty, shorter than 32 characters or cannot be read, a write that carries an `Idempotency-Key` is answered 503 `{"code":"unavailable"}` before anything runs or is written, and `console.error` gets one line `{"yumemi":"idempotency.key_missing","binding":"IDEMPOTENCY_HASH_KEY","reason":"absent"|"short"|"unreadable","service":…}` (no value). It never falls back to an unkeyed hash and never runs the write without its record. Writes without the header, read Services, ports and attached routes are unaffected. The client keeps the key and the input on a 503, so the user's retry goes through once the secret is in.
- **Rotating the key.** A record is also compared under `IDEMPOTENCY_HASH_KEY_PREVIOUS` (optional, same forms), so a retry of a write recorded under the old key is still replayed (same body) or 409 (other body) after the switch; new records always use the current key. Rotate in three steps: (1) set `IDEMPOTENCY_HASH_KEY_PREVIOUS` to the current key's value (nothing changes yet); (2) set `IDEMPOTENCY_HASH_KEY` to the new value; (3) after the retention window plus the cron interval (by default 24 hours plus the time between two scheduled runs) remove `IDEMPOTENCY_HASH_KEY_PREVIOUS`. Setting the previous key first means no request ever sees the new key without the old one. A record whose key has already been removed from both bindings is answered 409, never written a second time. The comparison only works forward: while a deploy is still reaching every isolate, a retry of a record made under the new key that lands on an isolate holding only the old key is answered 409 (not a second write), and so is a 0.13.2 `h1:` record retried on a 0.13.1 isolate during the upgrade or after a rollback to 0.13.1.
- **Rows from 0.13.1 are compared, not rewritten.** A row whose `request_hash` is 64 hex digits without the `h1:` mark (written by 0.13.0–0.13.1) is compared with the plain SHA-256 of the request, so a retry that straddles the upgrade is replayed (same body) or 409 (other body) exactly as before; no new row is ever written that way, and the cron purges the old rows within the retention window. A value of any other form is answered 409. Copies of the table (point-in-time restore, backups) taken before the upgrade still hold the unkeyed hashes until they expire.

0.14 tells the pages that are reading an Entity when someone else's write to it commits. **The signal is one word (`1`) over a WebSocket: no body, no diff, no value of the Entity.** The page that gets it reads again through the normal read Service, so whatever the reader may see is decided by the read as before. Using it takes three things in the app's Wrangler config and none in the declarations: the Durable Object binding, its migration and a secret.

- **Where a signal goes.** The destination is a Service's root Entity and the id of its root row (`<entity>:<id>`, for example `note:…`). The generator writes the table in `src/gen/registry.mjs` (`export const live = { note_edit: ['note', 'id'], … }`) and ★ writes nothing: a read and a write whose root is the same Entity meet on the same destination. Its write rows are every write Service with a root Entity; **since 0.14.1 its read rows are only the read Services of Blocks that some face's Page places as `Live`** (in 0.14.0 they were every read with a root Entity). The generator reads the faces and the api in the same run, so the api's table knows the faces' `Live` Blocks without the api reading any face declaration at run time. A write that changes rows under another root (a list's order, an inbox count) does not signal that root's readers in 0.14.
- **A read carries a token.** A read Service in the `live` table (the read of a `Live` Block, 0.14.1) that answers 200 on a session entrance (not an API-key one) gets the header `x-yumemi-live: <payload>.<signature>` (both base64url). The payload is `{"to":"<entity>:<id>","party":<the session's party>,"exp":<seconds>}`, one hour out; a read without a session is bound to the browser instead, `{"to":…,"party":null,"browser":<mark>,"exp":…}`, where the mark is the first 16 bytes of the HMAC of the `browser` cookie's id under the same key (the id itself is not in the token), and a read without a session and without a `browser` cookie gets no token, so no token is good for whoever holds it. The signature is the HMAC-SHA256 under `YUMEMI_LIVE_KEY` of `yumemi-live/1\n<payload>`. A read that did not pass (403, 404, a business failure) gets none, so only someone who could read the Entity just now holds a token for it. A read answered by the app's `respond` hook with its own `Response` gets none either. **A read that is not in the table gets no token and no `x-yumemi-live` header at all (0.14.1)**, even with a root Entity and a session: a token says "this person may hear when this root is written", and only a `Live` Block's read needs that. A `Live` Block's read must keep to the root's parties: a clause whose `owner` is `Self` or `Via<Entity>Party` narrows the root's rows to the session's party and passes; an `Anyone` clause, a `Party` × `NoOwner` clause (anyone with a session passes on any row of the root) and a clause the generator cannot read stop it (exit 4, see what the generator stops); an Entity subject × `NoOwner` (`Staff`, `AsFan`) is let in with a warning (exit 0), since the generator cannot tell a trusted role from one anyone may sign up for. Narrowing by `owner` is not the whole answer: a party of the root still hears the time of every write under that root, including writes it may not read itself (a shop's private note under a cast member's root reaches that cast member as a signal); which writes go under a `Live` root is ★'s call. In 0.14.0 every read with a root Entity carried one, so a public read (`Anyone`) handed anyone a token that heard the same root's non-public writes (a ledger kept under the same root, say) as they committed; one word each, but at any time and for as long as the reader kept reading the public page. A page that holds a 0.14.0 token gets the new rule's token, or none, the next time it reads. The socket checks the token, not the table, so a 0.14.0 token is accepted until its `exp` (at most an hour after the upgrade); changing `YUMEMI_LIVE_KEY` without `YUMEMI_LIVE_KEY_PREVIOUS` at the upgrade refuses those tokens (`signature`, see rotating the key below), and sockets already open end at their token's expiry at the latest.
- **The socket.** `GET <entrance prefix>/_yumemi/live?token=<token>` with `Upgrade: websocket` goes through the entrance's session checks and then, in order: the binding and the key are there, `Origin` is `https://` + the entrance's host (or the app's `origin` hook), the signature, the expiry, and the token's party equals the request's session party (a token without a party only for a request without a session, whose `browser` cookie has the token's mark). Then the entrance hands the destination's `YumemiLive` an internal request that carries the token's expiry and party; the object keeps them on the socket and closes it at the expiry (close code `4001`, reason `expired`, through an alarm), and `publish()` never sends to a socket past its expiry, so a socket opened before a logout or before the reader lost access hears at most until its token expires (one hour). A page reads again and opens a new socket with the new token. Anything else is 403 `{"code":"forbidden"}` and one line `{"yumemi":"live.refused","reason":"upgrade"|"binding"|"key"|"origin"|"token"|"signature"|"expired"|"party"|"browser"|<the entrance's refusal>,"entry":…}`; the framework's lines never hold the token, the key or the destination. **The token travels in the URL** (a browser's WebSocket cannot send headers), so Cloudflare's request logs (Workers Logs, Logpush, `wrangler tail`) keep it with the URL; it holds the destination and the party, and it does not open a socket by itself: the session cookie and the `Origin` (or, without a session, the `browser` cookie) are needed too.
- **Rotating the key.** A token is also checked under `YUMEMI_LIVE_KEY_PREVIOUS` (optional, same forms; a short or unreadable one is not used and logs `live.key_missing` with its binding name); new tokens always use `YUMEMI_LIVE_KEY`. Rotate in three steps: (1) set `YUMEMI_LIVE_KEY_PREVIOUS` to the current key's value; (2) set `YUMEMI_LIVE_KEY` to the new value; (3) after an hour (the token's lifetime) remove `YUMEMI_LIVE_KEY_PREVIOUS`. Switching the key without the previous one refuses every token in use (`signature`) until the pages read again.
- **A write signals after it commits, without holding the answer.** When a write Service's transaction commits, the entrance hands `publish()` on the destination's `YumemiLive` to `waitUntil` and answers at once; the key is checked inside it too. A business failure, a refusal (`step.reject`, which commits only its own row), an idempotent replay and a write refused by its root (404) send nothing. A publish that fails (the object or the namespace throws) is one line `{"yumemi":"live.publish_failed","service":…,"name":…}` and the write's answer is unchanged. A write that commits and then fails while its answer is built (a 5xx) still signals. A write answered `Accepted` (`step.commit`) signals once, when the HTTP request's transaction (with the outbox's parent row) commits; the rows the queue consumer writes later send nothing, nor do writes run by the cron, in 0.14 (only the HTTP entrance has the `waitUntil`). Signals may be lost: a page reads again when it reconnects.
- **`YumemiLive`.** The generated `shell.mjs` exports the class (from `yumemi/server/worker.mjs`). It keeps no stored values (only an alarm for the next expiry), accepts sockets with the Hibernation WebSocket API, sends `1` to every socket within its expiry on `publish()` and answers `ping` with `pong` through the auto response (the object is not woken). A ★ Durable Object may not be named `YumemiLive` (exit 4).
- **No binding, nothing changes.** Without the `YUMEMI_LIVE` binding there are no tokens and no signals, and the socket is 403 (`binding`). With the binding but without `YUMEMI_LIVE_KEY` (missing, empty, shorter than 32 characters, unreadable; a Secret Store binding or a plain secret, as `IDEMPOTENCY_HASH_KEY`) reads answer without a token, writes send nothing, the socket is 403 (`key`), and each such read in the table or write logs `{"yumemi":"live.key_missing","binding":"YUMEMI_LIVE_KEY","reason":…,"service":…}`. Reads and writes themselves never fail for it.
- **The app's three steps** (Wrangler config of the api Worker, nothing in `src/`):

```toml
[[durable_objects.bindings]]
name = "YUMEMI_LIVE"
class_name = "YumemiLive"

[[migrations]]
tag = "yumemi-live"
new_sqlite_classes = ["YumemiLive"]
```

  and `wrangler secret put YUMEMI_LIVE_KEY` (`openssl rand -hex 32`). The class stores no values (it sets only an alarm), but a Durable Object class still needs a migration; `new_sqlite_classes` is the kind every plan accepts.
- **Generated output (api).** `src/gen/registry.mjs` gains the `live` table, `src/gen/http_runtime.mjs` passes it to the entrance, and `src/gen/shell.mjs` exports `YumemiLive`. The api side adds no public Gleam type and no DDL.

On a face, **★ writes one word: `Live` in place of `Fixed`** in a Page's placements. The Block is read again and applied in place when a write to its read's root Entity commits; what the user is typing (an IME composition included), open `details` and the scroll position stay.

```gleam
import yumemi/front.{Bottom, Flow, Live}

placements: [
  Live(area: "page", block: blocks.ChatThread, cell: Flow, edge: Bottom),
],
```

```gleam
// in the Block: key the rows, and say where "new lines" are
html.ol(css.class(lines), [], [
  el.each_keyed(it.lines, fn(line) { message_id.to_string(line.message) }, fn(line) {
    line_view(line)
  }),
]),
el.fresh(css.class(link), [el.text("新しい発言があります")]),
```

- **`Live(area:, block:, cell:, edge:)`** is placed like `Fixed`. The destination is derived (the Block's read Service's root Entity and its id, as above); ★ writes no socket, no destination, no reconnect, no draft check and no scroll code. `edge` is where new things arrive: `Bottom` follows when the reader is at the bottom and otherwise stays and shows `el.fresh`; `Top` stays at the top when the reader is there and otherwise keeps the visible line where it was and shows `el.fresh`; `Anywhere` keeps the visible line and shows nothing. Without JavaScript nothing changes: there is no socket, `el.fresh` stays `hidden`, and a link that reloads the page (★'s own) works as before.
- **`el.each_keyed(items, key, view)`** puts `data-yumemi-key` on each row's root element (not on a text or fragment root). Keys must be unique in the list. Rows that hold an interactive Component or a `details` need keys: without them, a line inserted before an open `details` would move the open state and the draft to another row.
- **`el.fresh(class, children)`** is a `<button hidden data-yumemi-fresh>` the runtime shows when a refresh changed the Block while the reader was away from the edge; pressing it goes to the edge and hides it again, and so does scrolling to the edge.
- **What the generator stops (exit 4).** `Live` in the Layout (Page placements only in 0.14), in a `pc` or `tablet` Frame's placements (only `sp` placements are drawn), the same Block `Live` twice on one Page, an `edge` other than the three, a Block that does not take a read Service's `Out`, a Block whose Service is a write, a Block whose Service has no root Entity (no destination), and (0.14.1) a Block whose Service is public, with an `Anyone` clause in its `allow`: its token would let anyone, signed in or not, hear when the root is written by any write, including writes the public may not see (`… の allow に Anyone がある(公開の読みの札では、ログインしていない人も同じ root の非公開の書きの時刻を聞ける。Live の Block は root の当事者だけが通る読みにする)`). Also (0.14.1) a `Party` × `NoOwner` clause, shorthand (`allow.Party`) or `Clause(who: Party, owner: NoOwner, ..)` with any `at`: anyone with a session passes on any row of the root, so a signed-in third party could hear the root's writes (`… の allow の句 Party(owner: NoOwner)は session があれば誰でも root のどの行も通す(ログインした第三者が同じ root の書きの時刻を聞ける。owner を Self か Via<Entity>Party にする)`); and a clause the generator cannot read (a constant, a spread, an `allow` that is not a List literal), which it cannot judge, as when it writes the read's SQL (`… の allow の句が読めない: …`). An Entity subject × `NoOwner` (`Staff`, `AsFan`, the `gen/allow` shorthand `allow.staff`) is a warning (exit 0, `… の allow の句 Staff(owner: NoOwner)は Staff なら誰でも root のどの行も通す(…)`): whether that role is trusted or open to anyone is ★'s to know. A clause whose `owner` is `Self` or `Via<Entity>Party` passes. A `Live` Block's read is one only the root's parties pass; a page that is public and must still follow writes is not served by `Live` in 0.14.1. **Warnings (exit 0):** a keyless list in the Block (`el.each`, `list.map`, `list.index_map`, `list.flat_map`) whose rows hold an interactive Component or a plain `details` (`html.details`, `el.element("details", …)`), directly or through functions of the same module, and `edge: Bottom` without `el.fresh` in the Block. The check reads the Block's text, so it does not see rows built by functions of another module, by recursion or `list.fold`, or a Component or `details` passed in as a value; rows like these need `el.each_keyed` by ★'s own judgement.
- **What the face does.** The shell wraps the placement in `<yumemi-live name edge token>` (`display: contents`, so the Area's flow is unchanged) and copies the read's `x-yumemi-live` into `token` (no attribute when the api gives none: then the page opens no socket). A GET of the same URL with the header `x-yumemi-block: <name>` (the Block's name in snake case) goes through the gate like the page (declarations, consents, session) and answers only `<style>` (the rules of the classes the Block used) and the `<yumemi-live>` element, `cache-control: no-store`: it reads the session if the Vars need it, the Block's read Service, and every other read of the Page and its Layout that is not `optional` (for their 403/404; their bodies are dropped). `optional` reads (the Layout's widgets, for example) are not read. The gate does not count it (no `<meta name="yumemi-pageview">`). A name that is not a Block of the Page (a Layout's Block, a `Widget`'s Block, any other name) is 404 before any read; a read that is 403 or 404 gives the same status. Since 0.14.1 the same answer serves the Page's `Fixed` Blocks too (below).
- **What the browser does** (`yumemi/front/live_block.mjs`, started by the generated `client.mjs`). It opens `wss://<host><entrance prefix>/_yumemi/live?token=…` with the token. On `1` it waits 0–500 ms (so a page many people watch does not refresh all at once), fetches the fragment and applies it; signals that arrive while a fetch is in flight fold into one more fetch. A gate redirect, 403 or 404 (and a 200 that is not the fragment) reloads the whole page (the client navigation's reload, or a page load); a 5xx, any other status and a network failure leave the page as it is and fetch again after 1 s, doubling up to 30 s, each wait jittered. The fragment's style rules that the document's current stylesheets do not have are added to one constructed stylesheet; the set of present rules is rebuilt from the document at every fetch, so a rule whose page `<style>` went away with a client navigation is added again. The element is applied by four rules: matched nodes never move (a forward-only match). The match does not skip over a node that holds focus, a Component with a draft or a control with a draft (and does not match such a node to a new node that cannot hold them) when a later new node can take it (the same key, holding the same Component or control); the new node in front is inserted instead. So a focused node or a draft leaves the document only when the new HTML has no node that can take it. Open `details` are not guarded this way: in keyless rows they may move to another row (the generator warns); an interactive Component whose tag and `data-yumemi-args` are the same is not touched inside, and one whose Args changed is replaced only if its controls still hold the values they had when it connected and nothing in it has focus, otherwise it stays and gets `:state(stale)` (`data-yumemi-state~="stale"` where custom states are missing); the user's attributes stay (`open` of `details` and `dialog`, the value of a focused control, `hidden` of `el.fresh`), and an escape whose server attributes are unchanged is not touched; the key is `data-yumemi-key`, then a Component's tag and Args, then the tag. The token that comes with a fragment is kept for the next socket; the socket itself lives until its token's expiry.
- **Reconnecting.** Every time the socket opens (the first time too) the Block is read once, after the same 0–500 ms jitter, so writes between the page's render (or the last close) and the open are not lost. A dropped socket is reopened after 1 s, doubling up to 30 s, each wait jittered (between half and all of it), so a deploy that drops everyone's socket does not bring everyone back at once; the wait goes back to 1 s only after a socket stayed open for 30 s, so a socket closed right after it opens is retried with doubling waits too. A socket closed for its expiry (`4001`) or refused before it opened waits the same way, reads the Block first and opens with the new token. Only the token drawn in the page has its `exp` looked at: under a minute left, the Block is read before the socket opens; otherwise the Block is read once a minute before the `exp` and the socket reopened with the new token. A token that came with a fragment is opened without looking at its `exp` (the server's `4001` ends it), so a client clock that is off does not loop. When the page becomes visible again (`visibilitychange`) a pending reconnect runs at once; with an open socket the Block is read once.
- **For escapes.** `mount(element, yumemi)` gets a second argument on a face with `Live`: `yumemi.block(name, { href })` reads the Block `name` of `href` (default: the current URL). On the current URL it refreshes and applies the `<yumemi-live>` in place, as a signal would, and returns it; on another URL it returns that Block's `<yumemi-live>` element, not in the document, with its style rules already added and the URL it came from in `href`, for the escape to place (for example with `replaceWith`). A placed element reads again from its `href` on a signal and on `visibilitychange`, and `yumemi.block(name, { href })` with that URL refreshes it in place. It returns `null` when the gate answers no fragment. Since 0.14.1 every face with escapes passes `yumemi.block`, and it also reads Blocks that are not `Live` (below).
- **Not in 0.14.** The writer's own `ReloadPage` still replaces the body (it is not a morph yet). Rows under another root (a list's order, an inbox count) do not move. Two `Live` Blocks with different destinations open two sockets.
- **Blocks that are not `Live` (0.14.1).** The fragment answer also serves every `Fixed` Block of the Page's `sp` placements, on every face, with the same gate, Vars, session and reads as a `Live` Block (the Block's read Service, and the Page's and Layout's reads that are not `optional`, for their 403/404). A Block that reads no Service (`In = Nil`) is drawn from the Vars alone; the Page's root read still runs for its status. The answer is `<style>` and `<yumemi-block name>` (`display: contents`, no token): the page itself does not wrap its `Fixed` Blocks, only the fragment does. When a Page places the same Block twice, the first placement (and its cell) answers; when a Block is `Live` on the Page, the `Live` one answers. Layout Blocks and `Widget` Blocks stay 404. `yumemi.block(name, { href })` returns that `<yumemi-block>` (not in the document, its style rules already added, with the URL it came from in `href`, also on the current URL), for the escape to place. It has no signal and never reads again by itself (not on `visibilitychange` either); `yumemi.block` with the same URL reads it again and applies it in place by the same four rules and returns it, or returns `null` (and leaves the page and the placed Block as they are) for a redirect, 403, 404, 5xx or a network failure. A face without `Live` loads `yumemi/front/block.mjs` only (the fragment, the style rules and the morph; no token, no socket), and only when it has escapes; `live_block.mjs` builds on it.
- **Generated output (face).** `src/gen/load/**` gains a `live_<name>` function per `Live` Block and (0.14.1) a `block_<name>` function per `Fixed` Block of the Page, `src/gen/shell.mjs` the Page's `lives` and (0.14.1) `blocks` tables and the fragment answer, `src/gen/gate.mjs` the header check (0.14.1: on every face that has a fragment answer), and `priv/static/_yumemi/client.mjs` the runtime (`live_block.mjs` on a face with `Live`; 0.14.1: `block.mjs` on a face with escapes and no `Live`). The page HTML of a face without `Live` is unchanged.


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
| `framework/browser` | browser id, at, kind (0.12) | the `Declare(attached, kind)` attached route, once per declared kind |
| `framework/audit` | seed, stage, service, party, outcome, at | one row per entrance stage |
| `framework/outbox_parent` | id, dedupe key, payload (json), event id, at, folded | outbox parent row of a write |
| `framework/outbox_child` | id, kind, payload (json), parent id, at | outbox child row (one queue message) |
| `framework/outbox_done` | event id | mark a consumed event done |
| `framework/outbox_get` | id | load a queued message |
| `framework/outbox_sent` | id | mark a swept message sent (not called since 0.11.6) |
| `framework/outbox_sweep` | kinds | list unsent messages to resend |
| `framework/outbox_claim` | id | claim one swept row before sending it (0.11.6; generated by default, see above) |
| `framework/pageview_record` | event id, mark, face, at, kind, path, prev, referrer path, referrer host, client at, party, extra (json), dims (json), excluded | one counted event into the `Store` (0.12; generated by default, calls `framework.pageview_record` from `db/framework/pageview.sql`) |
| `framework/pageview_rollup` | at | the daily rollup of the `Store` (0.12; generated by default) |
| `framework/idempotency_find` | party, key | look up a recorded response before a keyed write and after its failure (0.13; generated by default) |
| `framework/idempotency_record` | party, key, request hash, result (json), at | record a keyed write's response, first in the write's transaction (0.13; generated by default) |
| `framework/idempotency_repair` | party, key, result (json) | replace a record whose response changed by `RETURNING` (0.13; generated by default) |
| `verb/create_<entity>_idempotency_order` | party, key, mark, created key, fallback | put the created row's `order` into the record in the create's transaction (0.13 r2; generated for an ordered Entity's create) |
| `framework/idempotency_sweep` | before | delete records older than the retention window (0.13; generated by default) |

**Cron** — a face whose gate counts into the framework `Store` makes the generated `shell.mjs` run the rollup on the cron expression `0 1 * * *` (01:00 UTC, fixed by the framework). Add that expression to the Worker's `triggers.crons`.

**Worker env** — `DATABASE_URL`, optionally `DLEAM_SQL_ENDPOINT` (0.13, the SQL endpoint) and `IDEMPOTENCY_RETENTION_HOURS` (0.13, default 24), `IDEMPOTENCY_HASH_KEY` (0.13.2, required for keyed writes; a Secret Store binding or a secret, at least 32 characters) and optionally `IDEMPOTENCY_HASH_KEY_PREVIOUS` (0.13.2, while rotating), `COOKIE_DOMAIN`, `OUTBOX` (queue binding), `<ENTRY>_HOST` per entrance, the `key_binding` of `browser` (a Secret Store binding), the KEK bindings of `Sealed` properties, optionally `YUMEMI_LIVE` (0.14, the `YumemiLive` Durable Object namespace) with `YUMEMI_LIVE_KEY` (0.14, a Secret Store binding or a secret, at least 32 characters) and optionally `YUMEMI_LIVE_KEY_PREVIOUS` (0.14, while rotating), and optionally `ISOLATE_MARKER=1` (test header).

## `yumemi/server` ── Storage: where an Entity's table is and what it holds (0.14.5, 0.14.6)

`pub const storage: List(server.Storage)` in `src/server.gleam` overrides how the generator derives an Entity's table. `InObject` keeps the Entity in a Durable Object instead of Postgres; `Column`, `Text`, `Split` and `Array` change how one Property sits in its columns. The holes stay one per Property; the SQL does the mapping. 0.14.5 adds two more. An app that declares neither generates the same files as with 0.14.4, byte for byte.

- **`InSchema(entity:, schema:)`** puts the Entity's table in another schema than `app`. Every generated statement names the table `<schema>.<table>`: the verbs, the reads (`FROM`, `JOIN`, `EXISTS`, the `with` children, the relation reads) and the `allow` clauses. Without it the table stays in `app`. The schema must be a plain SQL identifier (`[a-z_][a-z0-9_]*`) and not `framework`, at most one per Entity and not on an `InObject` Entity (exit 4). Creating the table there is the app's DDL, as before.
- **`Derived(entity:, property:)`** declares a Property the table has no column for: the SQL that reads the Entity hands its value in from another table (a `JOIN`), under the Property's name. The generator writes no column for it: it leaves the Property out of the create and update verbs' columns and values, `RETURNING`, the `Draft` and `Created` types and the runtime's verb table, and generates no `update_<entity>_<property>`. The row decoders (the generated one or a `decode_<name>` hook) still read it, so **every read that hands the Entity's rows must pass it**: the hand-written root and `ManualRead` statements, e.g. `JOIN … l ON …` with `l.<column> AS <property>` (or `to_jsonb(t) || jsonb_build_object('<property>', l.<column>)`). Without `ReadFrom` (below) a generated read cannot, so one that hands the Entity's whole rows (`t.*` of `from`, a `join`'s `to_jsonb`, a `with` child without `Pick`, a relation read) is not written and stops the generator (exit 4, `… の行を生成の読みで渡せない …`), and so does a generated read naming the Property in `where`, `order`, `group` or `Pick`, filtering by it as the `party` of an `allow` owner (`Via<Entity>Party`) or ordering `with` children by it as `order`; pick the other columns with `q.Pick` or write the read by hand. `Derived` stops the generator (exit 4) on a Property the verbs write or the table needs: a key or `auto_key`, the `upsert_key`, the `ordered_by` field or its `within`, `version`, the Lifecycle phase, a relation Property, a field of a `verbs.Update` or `verbs.DeleteWhere`, an `InObject` Entity's Property, or one that also has `Column`, `Text`, `Split`, `Array` or a second `Derived`.
- **`ReadFrom(entity:, relation:)`** (0.14.6) makes the generated reads of the Entity read another relation than its table, typically a view that joins in the `Derived` values: `ReadFrom(entity: "store", relation: "store_view")` with `CREATE VIEW app.store_view AS SELECT l.<column> AS <property>, s.* FROM app.store s LEFT JOIN … l ON …`. `relation` is a name in the Entity's schema (`app`, or the `InSchema` one). Every generated read names `<schema>.<relation>` where it named the table: the `from`, the `join`s, the relation reads (`to_<property>`), the `has` `EXISTS`, the `allow` clauses' path and the `with` children. The verbs (create, update, put, delete, their `RETURNING`, the statements that lock rows with `FOR UPDATE`) and the foreign keys still name the table, so the relation is never written. On an Entity with `ReadFrom`, the generated reads may hand its whole rows and name its `Derived` Properties (the relation has those columns), so the reads `Derived` alone stops are written; what `Derived` takes out of the verbs, `Draft` and `Created` stays out. `ReadFrom` without `Derived` is allowed. The relation must be a plain SQL identifier, at most one per Entity and not on an `InObject` Entity (exit 4). Creating the relation, and keeping its columns those of the table plus the `Derived` ones, is the app's DDL. An app that declares no `ReadFrom` generates the same files as with 0.14.5, byte for byte.

## The gate and the CMS features (0.12)

0.12 moves the features every business CMS needs into the framework: declarations, consents, counting pageviews (with uniques and visits), the CSP and image variants. The app only names kinds and values in closed vocabularies; nothing application-specific is spelled in the framework, the runtime or the generator. This is a breaking change.

**The gate** (`<face>/src/gate.gleam`, `pub const gate: Gate`):

```gleam
Gate(
  sign_in: SignIn(path:, fallback_origin:),
  rules: List(Rule),            // Rule(pages, except, checks)
  redirects: List(Redirect),    // Redirect(pages, when, to)
  csp: List(Csp),               // was frame_src (the entry's frame_src is gone too)
  pageview: Pageview,           // NoPageview | Pageview(pages, only, fields, sink)
)
Check = SignedIn(fail) | Declared(kind, fail) | SubjectKind(kinds, fail) | Consented(kind, fail)
When  = WhenDeclared(kind) | WhenSignedIn
```

- **Failure texts.** These are every body the generated gate and shell answer on their own (a check's `Fail` answers with what the app wrote: `RedirectBack`, `ToSignIn`, or a `Deny` body):
  - `503 unavailable` — the session read (gate or shell) or a Page read (shell) answered 5xx, threw from the `APP` binding, or the session body was not JSON, and a gate without a session route. Never folded into `401`, `403` or an anonymous page; the original status and the cause go to `console.error`. When the gate cannot read the session on a page none of its rules or redirects cover, it hands the page on as not read, and the shell reads the session itself if the page needs it.
  - `401 unauthorized` (shell) — a non-`Option` session field (`FromSession`) and no subject: the session is anonymous or its read answered 4xx. An `Option` field gets `None` and the page renders.
  - `403 forbidden` — the gate refused a permission (a subject mismatch, or a session read that answered 4xx other than 404 on a check; a 401 or 403 on a `signed-in` check goes to its `Fail`), or a Page read answered 403.
  - `404 not found` — the gate's session read answered 404 on a check, the root Page read answered 404, or no page matches and there is no `SVELTE` binding (a widget read's 404 renders the widget as `None`).
  - `<status> root read failed` / `<status> widget read failed` (shell) — a Page read answered another 4xx; the status is the read's.
  - `500 PUBLIC_<NAME>_ORIGIN` / `500 PUBLIC_IDP_ORIGIN` (shell) — the origin variable a page reads is unset or empty; the body is the variable's name.
  - `500 invalid variable source` (shell) — a page variable with a source the shell does not know (a generator bug).

**Declarations** (`Declared(kind)`) are browser-level statements such as an age declaration. The app names the kinds in `src/server.gleam`:

```gleam
pub const browser: BrowserCookie = BrowserCookie(
  cookie: "_b", key_binding: "BROWSER_KEY", max_age_days: 400,
  declarations: [Declaration(kind: "<kind>", claim: "<kind>_declared_at", max_age_days: 395)],
)
```

- The same `Declared(kind)` shape is written in four places: the gate check, `When`, a Service's `requires`, and the attached roles `Declare(attached, kind)` (sets the declaration) / `NeedsDeclared(attached, kind)` (403 without it). A kind that is not in `browser.declarations`, or any declaration without `browser`, stops with exit 4 (rule 32); duplicated kinds or claims, a kind outside `[a-z][a-z0-9_]*` or a declaration longer than the cookie stop with exit 4 (rule 33).
- The signed cookie's payload is `{id, <claim>: time, ..}`. `id` (32 hex) is the browser mark; each declaration is a field on it. A declaration older than its own `max_age_days` reads as absent even while the cookie is valid. A 0.11 cookie (`{id, <claim>}`) reads as that declaration without being rewritten.
- A missing declaration answers `403 {"code": "declaration_missing", "declaration": "<kind>"}`. The `ReadSession` route returns `declared: {<kind>: true}` (and no other declaration field).

**Consents** (`Consented(kind)`, `ConsentedFor(kind, subject: fn(args) -> String)`) are party-level. The app lists the kinds in `src/server.gleam` (`pub const consents: List(String)`); a kind outside it in a requirement or a gate check stops with exit 4 (rule 40). `ConsentedFor` matches the consent's subject against `subject(args)`. A missing consent answers `403 {"code": "consent_missing", "consent": "<kind>"}`. `ReadSession` returns every consent the party holds as `consents: {<kind>: true}`.

**The CSP** is `csp: [Csp(pages: List(Match), directives: [FrameSrc(hosts) | ImgSrc(hosts) | ConnectSrc(hosts) | MediaSrc(hosts)])]`. The gate sets `content-security-policy` on HTML responses of the matched Pages (directives of every matching `Csp` merged in order, hosts as `https://<host>`). Every declared directive starts with `'self'`, added by the generator, because the pageview receiver, the client navigation fetch and `/media/...` live on the same origin: `ConnectSrc(["api.example"])` becomes `connect-src 'self' https://api.example`. There is no way to drop `'self'` in 0.12. Hosts are `[a-z0-9.-]+` with one optional leading `*.`; a page outside the face's routes or a bad host stops with exit 4 (rule 38). There is no `script-src`. Client navigation still moves only between Pages whose CSP string equals the current document's.

**Counting pageviews** (`Pageview(pages, only, fields, sink)`):

- `only` uses the gate's `When`. The gate checks it when it marks a page, and the receiver checks it again when an event arrives; the app writes the condition once.
- `fields` is closed: `NavKind` (`kind`: `initial` / `reload` / `spa`, back and forward are `spa`), `ClientAt`, `Path`, `Previous` (`prev`, the tab's previous event id), `Referrer` (`referrer_path` on the same origin, else `referrer_host`, only without a previous event) and `FromQuery(name, param, Slug(max))` (`[a-z0-9_]{1,max}`, max 1–64). No regular expression strings are accepted. The framework always adds the event `id`; the previous-event key is `yumemi:pageview:<face>`; the visit window (30 minutes) and the per-browser limit (60 per minute) are fixed. Duplicate field names, a `FromQuery` name that is one of the receiver's event fields (`id`, `kind`, `client_at`, `path`, `prev`, `referrer_path`, `referrer_host`), a bad `param` or `max` stop with exit 4 (rule 35); a page outside the routes stops with exit 4 (rule 34).
- **One sender.** The gate only adds `<meta name="yumemi-pageview">` to a counted page (200 HTML, a `pages` Page, `only` holds), on a page load and on a client navigation fetch alike; it emits no inline script. The sender is `yumemi/front/pageview.mjs`, started by the generated `client.mjs` (a face with a `pageview` gets a `client.mjs` even without islands). It posts once after a page load (after `requestIdleCallback`; a prerendered page waits for activation; a bfcache restore is not counted) and once per client navigation at the Navigation API's `navigatesuccess`, reading the mark in the current document. Only a navigation that was intercepted (`navigation.transition` is not `null` at `navigatesuccess`) counts; a fragment-only move and a same-document `history.pushState` / `replaceState` (an island updating the query) fire `navigatesuccess` too but are not counted. `navigate.mjs` does not send.
- **The receiver** is `<entry prefix>/_yumemi/pageviews` on the face's entry and always answers `202` with no body. It drops bots and monitors (`cf.verifiedBotCategory`, user agent) and prefetches (`Sec-Purpose: prefetch`) without a row, keeps only the declared fields, and drops malformed events, all silently. An unexpected failure (an SQL error such as a missing table, an exception from the Service, a missing configuration) still answers `202` but is written to `console.error`, so lost events can be found.
- **The browser mark** is set by the receiver: with `Store`, the first event that passes `only` from a browser without a valid cookie gets a mark-only cookie (`{id}`); with `ToService`, only such an event that also reaches a Service carrying the mark (`Carried(.., name: "browser", ..)`) gets one. The cookie has the `browser` cookie's attributes (`HttpOnly; Secure; SameSite=Lax; Max-Age=<max_age_days>`, `Domain=COOKIE_DOMAIN`). A later declaration adds its field to the same mark.
- `sink: Store(resolve: Option(String), rollup_by: List(String), exclude_when: List(String))` keeps events in framework tables (`framework.pageview_mark` / `_visit` / `_event` / `_rollup`); an event row keeps the mark and, when the request carries a signed-in session, its party (`party`). Same-id resends, the 61st event in a minute and two tabs at once are handled under the mark's row lock (`framework.pageview_record`). `resolve` names a Service with `Args(path: String)` whose `Out` carries the business dimensions; `rollup_by` names `Out` fields to roll up by, `exclude_when` names `Out` `Bool` fields whose true events are stored but not counted (the owner's and the operators' own views). The daily rollup (cron `0 1 * * *`) rebuilds the previous and the current UTC day and their months: page views, uniques (marks), visits and roaming visits (visits with 2+ views), per site, per path and per `rollup_by` field. A `Store` without `browser`, or whose `fields` lack `Path` (the store counts by path), stops with exit 3; an unknown `resolve` or field stops with exit 4 (rule 37).
- **The DDL is generated, not applied.** A `Store` makes the generator write `db/framework/pageview.sql` (tables, indexes and the three functions). Applying it to a database is the app's DDL step.
- `sink: ToService(service)` is a named escape hatch: the receiver runs its checks (fields, `only`, bots, prefetch) and calls the app's Service with Args built from the event fields (rule 36: `Args` must have `id`, else exit 3; every Args field must be one of the event's field names, fields that may be absent must be `Option`, and its type must decode from the event's value, a string, or one of `initial` / `reload` / `spa` for `kind`: `String`, a value type, an `arg_*` hook, `Datetime` for `client_at`, a bare enum with all three for `kind`, else exit 4; the Service's `allow` must have an `Anyone` or a `Party` clause, else exit 3, since the receiver passes events only through those two). The receiver evaluates the Service's `requires` (declarations and consents, as for any call) and the `anyone` / `party` clauses; an event that fails either never reaches the Service and sets no cookie. It does not apply `phaseGates`, `suspended`, or the `judge` / `write_gate` hooks. The mark is set only when the Service carries it (`Carried(.., name: "browser", ..)`); the mark, the party and the subject reach the root as usual. Resends, the per-minute limit and concurrent tabs are the Service's job. The generator counts it in the face's escape line (exit 0, also in `_diagnostics.txt`).
- **Who is responsible.** Pageview counting sets a signed, HttpOnly first-party cookie holding a random identifier, and sends only the fields you declare to your own API; nothing goes to third parties. Whether you must disclose this, ask for consent, or offer an opt-out depends on the laws that apply to your service (for example Japan's Telecommunications Business Act Art. 27-12 and the APPI, or the EU ePrivacy Directive Art. 5(3) and the GDPR). That responsibility lies with the operator of the application, not with yumemi; if your users need to opt in, count only after their action through `only`.

**Colours in Args.** A Service's `Args` field typed `color.Color` (or `Option(color.Color)`) is decoded with `color.parse`; a broken colour answers `400 invalid_argument` with its field and never reaches the Service.

**Image variants.** `pub const media: Media = Media(path:, variants: [ImageVariant(name:, width:, height: Option(Int), fit: ScaleDown | Cover | Contain)], theme_background:)` in `src/server.gleam` makes the generator write `<face>/src/gen/media.gleam` per face: a closed `Variant` type, `name(variant)`, `theme_background` and `url(blob, variant)` (`<path>/<key, each "/"-separated segment percent-encoded>?v=<name>`). Duplicate or badly spelled names, or a `theme_background` outside the table, stop with exit 4 (rule 39). Serving, caching and purging stay in the app.
