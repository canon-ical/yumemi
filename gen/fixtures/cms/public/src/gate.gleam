// ★ public/src/gate.gleam ── 面の門(0.12)。申告・同意・CSP・数える口を全部宣言する
import gleam/option.{Some}
import yumemi/gate.{
  ClientAt, ConnectSrc, Consented, Csp, Declared, Exact, FrameSrc, FromQuery,
  Gate, ImgSrc, MediaSrc, NavKind, Pageview, Path, Prefix, Previous, Redirect,
  RedirectBack, Referrer, Rule, SafeParam, SignIn, Slug, Store, ToSignIn,
  WhenDeclared,
}

pub const gate: gate.Gate = Gate(
  sign_in: SignIn(path: "/auth/sign-in", fallback_origin: "https://auth.example"),
  rules: [
    Rule(pages: [Exact("/status")], except: [], checks: [
      Declared(kind: "adult", fail: RedirectBack(location: "/", param: "next")),
    ]),
    Rule(pages: [Prefix("/article")], except: [], checks: [
      Consented(kind: "use", fail: ToSignIn(status: 302, back: True)),
    ]),
  ],
  redirects: [
    Redirect(
      pages: [Exact("/status")],
      when: WhenDeclared("region"),
      to: SafeParam(param: "returnTo", fallback: "/status"),
    ),
  ],
  csp: [
    Csp(pages: [Prefix("/article")], directives: [
      FrameSrc(["frames.example", "*.video.example"]),
      ImgSrc(["img.example"]),
    ]),
    Csp(pages: [Exact("/status")], directives: [
      ConnectSrc(["api.example"]),
      MediaSrc(["media.example"]),
    ]),
  ],
  pageview: Pageview(
    pages: [Prefix("/article"), Exact("/status")],
    only: [WhenDeclared("adult")],
    fields: [
      NavKind,
      ClientAt,
      Path,
      Previous,
      Referrer,
      FromQuery(name: "source_key", param: "r", pattern: Slug(max: 16)),
    ],
    sink: Store(
      resolve: Some("page_resolve"),
      rollup_by: ["section"],
      exclude_when: ["own"],
    ),
  ),
)
