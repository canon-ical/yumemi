import gleam/float
import gleam/int

pub type Track {
  Auto
  Fr(value: Int)
  Rem(value: Float)
  Px(value: Float)
  Minmax(min: TrackSize, max: TrackSize)
}

pub type TrackSize {
  AutoSize
  FrSize(value: Int)
  RemSize(value: Float)
  PxSize(value: Float)
}

pub fn to_css(track: Track) -> String {
  case track {
    Auto -> "auto"
    Fr(value) -> int.to_string(value) <> "fr"
    Rem(value) -> float.to_string(value) <> "rem"
    Px(value) -> float.to_string(value) <> "px"
    Minmax(min:, max:) ->
      "minmax(" <> size_to_css(min) <> ", " <> size_to_css(max) <> ")"
  }
}

fn size_to_css(size: TrackSize) -> String {
  case size {
    AutoSize -> "auto"
    FrSize(value) -> int.to_string(value) <> "fr"
    RemSize(value) -> float.to_string(value) <> "rem"
    PxSize(value) -> float.to_string(value) <> "px"
  }
}
