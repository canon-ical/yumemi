import entity/label.{type Label}
import yumemi/er.{type Multi}

pub type Photo {
  Photo(id: Int, labels: Multi(Label))
}

pub fn key(it: Photo) -> Int {
  it.id
}

pub const collection: String = "photos"
