# yumemi

**Have a sweet Gleam.** 設計を書けば、コードが生まれる。

A framework for [Gleam](https://gleam.run) on Cloudflare Workers. You describe an application in five words — Entity, Property, Type, Service, Authorization — and yumemi derives the Gleam implementation and every entrance to it: HTTP, MCP, CLI.

Open source, coming soon. https://gleam.canon-ical.com/

## Status

Extracted from the `framework/` directory of a production application on 2026-09-16, history included. Module namespace is still `framework/*`; the package name is `yumemi`. Published on Hex as [`yumemi`](https://hex.pm/packages/yumemi) (0.2.0 = the 2026-09-16 extraction; the generator and gen-3/gen-4 changes ship from 0.3.0).

## Layout

| Module | What |
|---|---|
| `framework/spec` `framework/er` | Entity / Property / Type ── the model and its derivation |
| `framework/entry` `framework/verb` `framework/party` `framework/require` | Entrances and Authorization |
| `framework/step` `framework/effect` `framework/query` `framework/io` | Service logic: read / guard / apply / call / done |
| `framework/connector` `framework/page` `framework/blob` `framework/vector` | Connectors, SSR pages, R2, Vectorize |
| `framework/secret` `framework/sealed` `framework/time` | Secrets, sealed values, time |

```
gleam build
```
