//// GENERATED from public/src/components/*.gleam [sha256:4b5b6b6d050b] — 手で編集しない

import components/article_blob_copy as article_blob_copy_component
import components/article_manage as article_manage_component
import components/blob_save as blob_save_component
import components/like_button as like_button_component
import components/pick_tag as pick_tag_component
import components/tag_filter as tag_filter_component
import components/title_lookup as title_lookup_component
import gen/live/article_blob_save as article_blob_save_live
import gen/live/article_create as article_create_live
import gen/live/article_publish as article_publish_live
import gen/live/article_title as article_title_live
import gen/live/blob_copy as blob_copy_live
import gen/live/widget_list as widget_list_live
import yumemi/front/el
import yumemi/front/live

pub fn article_blob_copy(blob_copy: blob_copy_live.Args) -> el.Element {
  live.component(
    "article-blob-copy",
    live.json_object([
      #("blob_copy", blob_copy_live.args_json(blob_copy)),
    ]),
    article_blob_copy_component.view(blob_copy),
  )
}

pub fn article_manage(
  article_publish: article_publish_live.Args,
  article_create: article_create_live.Args,
) -> el.Element {
  live.component(
    "article-manage",
    live.json_object([
      #("article_publish", article_publish_live.args_json(article_publish)),
      #("article_create", article_create_live.args_json(article_create)),
    ]),
    article_manage_component.view(article_publish, article_create),
  )
}

pub fn blob_save(article_blob_save: article_blob_save_live.Args) -> el.Element {
  live.component(
    "blob-save",
    live.json_object([
      #(
        "article_blob_save",
        article_blob_save_live.args_json(article_blob_save),
      ),
    ]),
    blob_save_component.view(article_blob_save),
  )
}

pub fn like_button(article_publish: article_publish_live.Args) -> el.Element {
  live.component(
    "like-button",
    live.json_object([
      #("article_publish", article_publish_live.args_json(article_publish)),
    ]),
    like_button_component.view(article_publish),
  )
}

pub fn pick_tag(
  article_create: article_create_live.Args,
  with: pick_tag_component.With,
) -> el.Element {
  live.component(
    "pick-tag",
    live.json_object([
      #("article_create", article_create_live.args_json(article_create)),
    ]),
    pick_tag_component.view(article_create, with),
  )
}

pub fn tag_filter(
  widget_list: widget_list_live.Args,
  with: tag_filter_component.With,
) -> el.Element {
  live.component(
    "tag-filter",
    live.json_object([
      #("widget_list", widget_list_live.args_json(widget_list)),
    ]),
    tag_filter_component.view(widget_list, with),
  )
}

pub fn title_lookup(article_title: article_title_live.Args) -> el.Element {
  live.component(
    "title-lookup",
    live.json_object([
      #("article_title", article_title_live.args_json(article_title)),
    ]),
    title_lookup_component.view(article_title),
  )
}
