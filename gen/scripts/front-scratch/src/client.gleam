import components/like_button
import lustre

pub fn main() -> Nil {
  let assert Ok(_) = lustre.register(like_button.app(), "like-button")
  Nil
}
