//// タグ(0.12、51 v6「html と el」)。業務の CMS の ★ が使う 53 種と SVG の `svg` / `path`、殻の部品。
//// 0.13.1 で文書の 8 種(`caption`・`del`・`em`・`h5`・`h6`・`i`・`kbd`・`sup`)を足した。
//// sketch_lustre の `html` と同じ名前・同じ引数の順(class を取る形と `_` の付く取らない形)。
//// `style`・`script`・`link` は置かない(生の CSS は `el.stylesheet`)。

import yumemi/front/css.{type Class}
import yumemi/front/el.{type Attribute, type Element}

fn tag(
  name: String,
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element(name, [attribute_class(class), ..attributes], children)
}

fn attribute_class(c: Class) -> Attribute {
  el.class_attribute(c)
}

pub fn a(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("a", class, attributes, children)
}

pub fn a_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("a", attributes, children)
}

pub fn article(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("article", class, attributes, children)
}

pub fn article_(
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element("article", attributes, children)
}

pub fn blockquote(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("blockquote", class, attributes, children)
}

pub fn blockquote_(
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element("blockquote", attributes, children)
}

pub fn br(class: Class, attributes: List(Attribute)) -> Element {
  tag("br", class, attributes, [])
}

pub fn br_(attributes: List(Attribute)) -> Element {
  el.element("br", attributes, [])
}

pub fn button(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("button", class, attributes, children)
}

pub fn button_(
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element("button", attributes, children)
}

pub fn caption(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("caption", class, attributes, children)
}

pub fn caption_(
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element("caption", attributes, children)
}

pub fn code(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("code", class, attributes, children)
}

pub fn code_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("code", attributes, children)
}

pub fn dd(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("dd", class, attributes, children)
}

pub fn dd_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("dd", attributes, children)
}

pub fn del(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("del", class, attributes, children)
}

pub fn del_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("del", attributes, children)
}

pub fn details(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("details", class, attributes, children)
}

pub fn details_(
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element("details", attributes, children)
}

pub fn dialog(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("dialog", class, attributes, children)
}

pub fn dialog_(
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element("dialog", attributes, children)
}

pub fn div(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("div", class, attributes, children)
}

pub fn div_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("div", attributes, children)
}

pub fn dl(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("dl", class, attributes, children)
}

pub fn dl_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("dl", attributes, children)
}

pub fn dt(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("dt", class, attributes, children)
}

pub fn dt_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("dt", attributes, children)
}

pub fn em(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("em", class, attributes, children)
}

pub fn em_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("em", attributes, children)
}

pub fn fieldset(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("fieldset", class, attributes, children)
}

pub fn fieldset_(
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element("fieldset", attributes, children)
}

pub fn footer(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("footer", class, attributes, children)
}

pub fn footer_(
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element("footer", attributes, children)
}

pub fn form(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("form", class, attributes, children)
}

pub fn form_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("form", attributes, children)
}

pub fn h1(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("h1", class, attributes, children)
}

pub fn h1_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("h1", attributes, children)
}

pub fn h2(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("h2", class, attributes, children)
}

pub fn h2_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("h2", attributes, children)
}

pub fn h3(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("h3", class, attributes, children)
}

pub fn h3_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("h3", attributes, children)
}

pub fn h4(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("h4", class, attributes, children)
}

pub fn h4_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("h4", attributes, children)
}

pub fn h5(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("h5", class, attributes, children)
}

pub fn h5_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("h5", attributes, children)
}

pub fn h6(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("h6", class, attributes, children)
}

pub fn h6_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("h6", attributes, children)
}

pub fn header(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("header", class, attributes, children)
}

pub fn header_(
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element("header", attributes, children)
}

pub fn hr(class: Class, attributes: List(Attribute)) -> Element {
  tag("hr", class, attributes, [])
}

pub fn hr_(attributes: List(Attribute)) -> Element {
  el.element("hr", attributes, [])
}

pub fn i(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("i", class, attributes, children)
}

pub fn i_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("i", attributes, children)
}

pub fn iframe(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("iframe", class, attributes, children)
}

pub fn iframe_(
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element("iframe", attributes, children)
}

pub fn img(class: Class, attributes: List(Attribute)) -> Element {
  tag("img", class, attributes, [])
}

pub fn img_(attributes: List(Attribute)) -> Element {
  el.element("img", attributes, [])
}

pub fn input(class: Class, attributes: List(Attribute)) -> Element {
  tag("input", class, attributes, [])
}

pub fn input_(attributes: List(Attribute)) -> Element {
  el.element("input", attributes, [])
}

pub fn kbd(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("kbd", class, attributes, children)
}

pub fn kbd_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("kbd", attributes, children)
}

pub fn label(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("label", class, attributes, children)
}

pub fn label_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("label", attributes, children)
}

pub fn legend(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("legend", class, attributes, children)
}

pub fn legend_(
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element("legend", attributes, children)
}

pub fn li(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("li", class, attributes, children)
}

pub fn li_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("li", attributes, children)
}

pub fn mark(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("mark", class, attributes, children)
}

pub fn mark_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("mark", attributes, children)
}

pub fn nav(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("nav", class, attributes, children)
}

pub fn nav_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("nav", attributes, children)
}

pub fn noscript(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("noscript", class, attributes, children)
}

pub fn noscript_(
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element("noscript", attributes, children)
}

pub fn ol(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("ol", class, attributes, children)
}

pub fn ol_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("ol", attributes, children)
}

pub fn optgroup(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("optgroup", class, attributes, children)
}

pub fn optgroup_(
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element("optgroup", attributes, children)
}

pub fn option(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("option", class, attributes, children)
}

pub fn option_(
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element("option", attributes, children)
}

pub fn p(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("p", class, attributes, children)
}

pub fn p_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("p", attributes, children)
}

pub fn pre(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("pre", class, attributes, children)
}

pub fn pre_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("pre", attributes, children)
}

pub fn progress(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("progress", class, attributes, children)
}

pub fn progress_(
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element("progress", attributes, children)
}

pub fn section(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("section", class, attributes, children)
}

pub fn section_(
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element("section", attributes, children)
}

pub fn select(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("select", class, attributes, children)
}

pub fn select_(
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element("select", attributes, children)
}

pub fn small(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("small", class, attributes, children)
}

pub fn small_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("small", attributes, children)
}

pub fn span(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("span", class, attributes, children)
}

pub fn span_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("span", attributes, children)
}

pub fn strong(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("strong", class, attributes, children)
}

pub fn strong_(
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element("strong", attributes, children)
}

pub fn summary(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("summary", class, attributes, children)
}

pub fn summary_(
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element("summary", attributes, children)
}

pub fn sup(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("sup", class, attributes, children)
}

pub fn sup_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("sup", attributes, children)
}

pub fn table(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("table", class, attributes, children)
}

pub fn table_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("table", attributes, children)
}

pub fn tbody(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("tbody", class, attributes, children)
}

pub fn tbody_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("tbody", attributes, children)
}

pub fn td(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("td", class, attributes, children)
}

pub fn td_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("td", attributes, children)
}

pub fn textarea(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("textarea", class, attributes, children)
}

pub fn textarea_(
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.element("textarea", attributes, children)
}

pub fn th(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("th", class, attributes, children)
}

pub fn th_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("th", attributes, children)
}

pub fn thead(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("thead", class, attributes, children)
}

pub fn thead_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("thead", attributes, children)
}

pub fn time(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("time", class, attributes, children)
}

pub fn time_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("time", attributes, children)
}

pub fn tr(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("tr", class, attributes, children)
}

pub fn tr_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("tr", attributes, children)
}

pub fn ul(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("ul", class, attributes, children)
}

pub fn ul_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("ul", attributes, children)
}

pub fn video(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("video", class, attributes, children)
}

pub fn video_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("video", attributes, children)
}

// 殻(生成物)が使う文書の部品。★ には出さない。

@internal
pub fn html(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("html", attributes, children)
}

@internal
pub fn head(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("head", attributes, children)
}

@internal
pub fn body_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.element("body", attributes, children)
}

@internal
pub fn meta(attributes: List(Attribute)) -> Element {
  el.element("meta", attributes, [])
}

@internal
pub fn title(attributes: List(Attribute), content: String) -> Element {
  el.element("title", attributes, [el.text(content)])
}

@internal
pub fn body(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  tag("body", class, attributes, children)
}

const svg_namespace = "http://www.w3.org/2000/svg"

/// SVG の根。名前空間(`xmlns`)は根に 1 回だけ出る。
pub fn svg(
  class: Class,
  attributes: List(Attribute),
  children: List(Element),
) -> Element {
  el.namespaced(
    svg_namespace,
    "svg",
    [attribute_class(class), ..attributes],
    children,
  )
}

pub fn svg_(attributes: List(Attribute), children: List(Element)) -> Element {
  el.namespaced(svg_namespace, "svg", attributes, children)
}

/// SVG の `path`。`svg` の子に置く。
pub fn path(d: String) -> Element {
  el.namespaced(svg_namespace, "path", [el.attribute("d", d)], [])
}
