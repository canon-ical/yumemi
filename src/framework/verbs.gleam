//// framework/verbs.gleam ── Entity の `pub const verbs` の語彙。
//// 1 手ごとの取り決めは Entity の性質。Service や SQL には書かない。

/// 1 手の取り決め。phase は Entity の Phase 型。
pub type Rule(phase) {
  /// 値を変える手に名前を付ける(pin / schedule の類)。
  Update(name: String, fields: List(String), at: Gate(phase))
  /// フェーズを進める手の版の取り決め。宣言が無ければ常に版を上げる。
  Advance(bump: Bump(phase))
  /// 親でない列での集合削除。delete_<entity>_by_<field> が出る。
  DeleteWhere(field: String)
  /// 集合作成。create_<entity 複数形> が出る。引数は List(<Entity>Draft)。
  CreateMany
  /// 一括でフェーズを進める ── 書けない。宣言があると生成器が止まる。
  AdvanceAll
}

pub type Gate(phase) {
  AnyPhase
  Only(List(phase))
}

pub type Bump(phase) {
  Always
  BumpUnless(from: phase, to: phase)
}

/// reorder の宣言用。順の列と並べ替えの範囲。
pub type Order {
  Order(field: String, within: String)
}
