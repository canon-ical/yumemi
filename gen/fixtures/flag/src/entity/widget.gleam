// ★ src/entity/widget.gleam
//// Entity Widget ── 置き場に並ぶ部品。真偽の列(visible)と、空きうる列(place)を持つ。
import gen/types/widget_id.{type WidgetId}
import gen/types/widget_name.{type WidgetName}
import gen/types/widget_place.{type WidgetPlace}
import gleam/option.{type Option}

pub type Widget {
  Widget(
    id: WidgetId,
    name: WidgetName,
    place: Option(WidgetPlace),
    visible: Bool,
    order: Int,
  )
}

pub fn key(it: Widget) -> WidgetId {
  it.id
}

pub const collection: String = "widgets"

// id は実行側が UUID を採番する。明示した key だけ Draft から除く。
pub const auto_key: List(String) = ["id"]
