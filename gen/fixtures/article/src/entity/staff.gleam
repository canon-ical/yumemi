// ★ src/entity/staff.gleam
//// Entity Staff ── この ER の中での「店の人」。
//// `PartyId` を1つ持つので、生成器はこれを主体 Entity として扱う(別の宣言は要らない)。
//// PartyId は IdP アプリ(ER {Party, Credential, Session})が発行した id の「値」で、
//// FK ではない ── Party はこのアプリの ER の外に居る(手順1「アプリ」節、第4〜6巡)。
////
//// 主体 Entity は初ログイン時にフレームワークが自動で作る(第7巡)。だから Property は
//// 「IdP 由来 / Option / 既定値あり」の3種しか置けない ── ここは3つとも IdP 由来。
import framework/idp.{type Email, type Name}
import framework/party.{type PartyId}

pub type Staff {
  Staff(party: PartyId, name: Name, email: Email)
}

/// PartyId が識別子。生成器はこの列に一意制約を張る。
pub fn key(it: Staff) -> PartyId {
  it.party
}

pub const collection: String = "staff"
