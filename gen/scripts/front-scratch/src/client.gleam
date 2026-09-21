import components/like_button
import components/pick_tag
import framework/front/live
import lustre

@external(javascript, "./client_ffi.mjs", "listenReload")
fn listen_reload(tag: String, callback: fn(Nil) -> Nil) -> Nil

@external(javascript, "./client_ffi.mjs", "reloadPage")
fn reload_page() -> Nil

pub fn main() -> Nil {
  let assert Ok(_) = lustre.register(like_button.app(), "like-button")
  let assert Ok(_) = lustre.register(pick_tag.app(), "pick-tag")
  listen_after_send(pick_tag.after_send, "pick-tag")
  Nil
}

fn listen_after_send(after_send: live.After, tag: String) -> Nil {
  case after_send {
    live.Stay -> Nil
    live.ReloadPage -> listen_reload(tag, fn(_unit) { reload_page() })
  }
}
