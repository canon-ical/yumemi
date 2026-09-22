// GENERATED from public/src/components/*.gleam and src/entry.gleam [sha256:4f2097e4dd4f] — 手で編集しない
// public/build/dev/javascript/prelude.mjs
var CustomType = class {
  withFields(fields) {
    let properties = Object.keys(this).map(
      (label2) => label2 in fields ? fields[label2] : this[label2]
    );
    return new this.constructor(...properties);
  }
};
var List = class {
  static fromArray(array3, tail) {
    return toList(array3, tail);
  }
  [Symbol.iterator]() {
    return new ListIterator(this);
  }
  toArray() {
    return [...this];
  }
  atLeastLength(desired) {
    let current = this;
    while (desired-- > 0 && current) current = current.tail;
    return current !== void 0;
  }
  hasLength(desired) {
    let current = this;
    while (desired-- > 0 && current) current = current.tail;
    return desired === -1 && current instanceof Empty;
  }
  countLength() {
    let current = this;
    let length2 = 0;
    while (current) {
      current = current.tail;
      length2++;
    }
    return length2 - 1;
  }
};
function prepend(element5, tail) {
  return new NonEmpty(element5, tail);
}
function toList(elements, tail) {
  let t = tail || List$Empty$const;
  for (let i = elements.length - 1; i >= 0; --i) {
    t = new NonEmpty(elements[i], t);
  }
  return t;
}
var ListIterator = class {
  #current;
  constructor(current) {
    this.#current = current;
  }
  next() {
    if (this.#current instanceof Empty) {
      return { done: true };
    } else {
      let { head, tail } = this.#current;
      this.#current = tail;
      return { value: head, done: false };
    }
  }
};
var Empty = class extends List {
};
var List$Empty$const = new Empty();
var List$Empty = () => List$Empty$const;
var List$isEmpty = (value2) => value2 instanceof Empty;
var NonEmpty = class extends List {
  constructor(head, tail) {
    super();
    this.head = head;
    this.tail = tail;
  }
};
var List$NonEmpty = (head, tail) => new NonEmpty(head, tail);
var List$isNonEmpty = (value2) => value2 instanceof NonEmpty;
var List$NonEmpty$first = (value2) => value2.head;
var List$NonEmpty$rest = (value2) => value2.tail;
var BitArray = class {
  /**
   * The size in bits of this bit array's data.
   *
   * @type {number}
   */
  bitSize;
  /**
   * The size in bytes of this bit array's data. If this bit array doesn't store
   * a whole number of bytes then this value is rounded up.
   *
   * @type {number}
   */
  byteSize;
  /**
   * The number of unused high bits in the first byte of this bit array's
   * buffer prior to the start of its data. The value of any unused high bits is
   * undefined.
   *
   * The bit offset will be in the range 0-7.
   *
   * @type {number}
   */
  bitOffset;
  /**
   * The raw bytes that hold this bit array's data.
   *
   * If `bitOffset` is not zero then there are unused high bits in the first
   * byte of this buffer.
   *
   * If `bitOffset + bitSize` is not a multiple of 8 then there are unused low
   * bits in the last byte of this buffer.
   *
   * @type {Uint8Array}
   */
  rawBuffer;
  /**
   * Constructs a new bit array from a `Uint8Array`, an optional size in
   * bits, and an optional bit offset.
   *
   * If no bit size is specified it is taken as `buffer.length * 8`, i.e. all
   * bytes in the buffer make up the new bit array's data.
   *
   * If no bit offset is specified it defaults to zero, i.e. there are no unused
   * high bits in the first byte of the buffer.
   *
   * @param {Uint8Array} buffer
   * @param {number} [bitSize]
   * @param {number} [bitOffset]
   */
  constructor(buffer, bitSize, bitOffset) {
    if (!(buffer instanceof Uint8Array)) {
      throw globalThis.Error(
        "BitArray can only be constructed from a Uint8Array"
      );
    }
    this.bitSize = bitSize ?? buffer.length * 8;
    this.byteSize = Math.trunc((this.bitSize + 7) / 8);
    this.bitOffset = bitOffset ?? 0;
    if (this.bitSize < 0) {
      throw globalThis.Error(`BitArray bit size is invalid: ${this.bitSize}`);
    }
    if (this.bitOffset < 0 || this.bitOffset > 7) {
      throw globalThis.Error(
        `BitArray bit offset is invalid: ${this.bitOffset}`
      );
    }
    if (buffer.length !== Math.trunc((this.bitOffset + this.bitSize + 7) / 8)) {
      throw globalThis.Error("BitArray buffer length is invalid");
    }
    this.rawBuffer = buffer;
  }
  /**
   * Returns a specific byte in this bit array. If the byte index is out of
   * range then `undefined` is returned.
   *
   * When returning the final byte of a bit array with a bit size that's not a
   * multiple of 8, the content of the unused low bits are undefined.
   *
   * @param {number} index
   * @returns {number | undefined}
   */
  byteAt(index4) {
    if (index4 < 0 || index4 >= this.byteSize) {
      return void 0;
    }
    return bitArrayByteAt(this.rawBuffer, this.bitOffset, index4);
  }
  equals(other) {
    if (this.bitSize !== other.bitSize) {
      return false;
    }
    const wholeByteCount = Math.trunc(this.bitSize / 8);
    if (this.bitOffset === 0 && other.bitOffset === 0) {
      for (let i = 0; i < wholeByteCount; i++) {
        if (this.rawBuffer[i] !== other.rawBuffer[i]) {
          return false;
        }
      }
      const trailingBitsCount = this.bitSize % 8;
      if (trailingBitsCount) {
        const unusedLowBitCount = 8 - trailingBitsCount;
        if (this.rawBuffer[wholeByteCount] >> unusedLowBitCount !== other.rawBuffer[wholeByteCount] >> unusedLowBitCount) {
          return false;
        }
      }
    } else {
      for (let i = 0; i < wholeByteCount; i++) {
        const a = bitArrayByteAt(this.rawBuffer, this.bitOffset, i);
        const b = bitArrayByteAt(other.rawBuffer, other.bitOffset, i);
        if (a !== b) {
          return false;
        }
      }
      const trailingBitsCount = this.bitSize % 8;
      if (trailingBitsCount) {
        const a = bitArrayByteAt(
          this.rawBuffer,
          this.bitOffset,
          wholeByteCount
        );
        const b = bitArrayByteAt(
          other.rawBuffer,
          other.bitOffset,
          wholeByteCount
        );
        const unusedLowBitCount = 8 - trailingBitsCount;
        if (a >> unusedLowBitCount !== b >> unusedLowBitCount) {
          return false;
        }
      }
    }
    return true;
  }
  /**
   * Returns this bit array's internal buffer.
   *
   * @deprecated
   *
   * @returns {Uint8Array}
   */
  get buffer() {
    if (this.bitOffset !== 0 || this.bitSize % 8 !== 0) {
      throw new globalThis.Error(
        "BitArray.buffer does not support unaligned bit arrays"
      );
    }
    return this.rawBuffer;
  }
  /**
   * Returns the length in bytes of this bit array's internal buffer.
   *
   * @deprecated
   *
   * @returns {number}
   */
  get length() {
    if (this.bitOffset !== 0 || this.bitSize % 8 !== 0) {
      throw new globalThis.Error(
        "BitArray.length does not support unaligned bit arrays"
      );
    }
    return this.rawBuffer.length;
  }
};
function bitArrayByteAt(buffer, bitOffset, index4) {
  if (bitOffset === 0) {
    return buffer[index4] ?? 0;
  } else {
    const a = buffer[index4] << bitOffset & 255;
    const b = buffer[index4 + 1] >> 8 - bitOffset;
    return a | b;
  }
}
var Result = class _Result extends CustomType {
  static isResult(data) {
    return data instanceof _Result;
  }
};
var Ok = class extends Result {
  constructor(value2) {
    super();
    this[0] = value2;
  }
  isOk() {
    return true;
  }
};
var Result$Ok = (value2) => new Ok(value2);
var Result$isOk = (value2) => value2 instanceof Ok;
var Result$Ok$0 = (value2) => value2[0];
var Error = class extends Result {
  constructor(detail) {
    super();
    this[0] = detail;
  }
  isOk() {
    return false;
  }
};
var Result$Error = (detail) => new Error(detail);
var Result$isError = (value2) => value2 instanceof Error;
function isEqual(x, y) {
  let values3 = [x, y];
  while (values3.length) {
    let a = values3.pop();
    let b = values3.pop();
    if (a === b) continue;
    if (!isObject(a) || !isObject(b)) return false;
    let unequal = !structurallyCompatibleObjects(a, b) || unequalDates(a, b) || unequalBuffers(a, b) || unequalArrays(a, b) || unequalMaps(a, b) || unequalSets(a, b) || unequalRegExps(a, b);
    if (unequal) return false;
    const proto = Object.getPrototypeOf(a);
    if (proto !== null && typeof proto.equals === "function") {
      try {
        if (a.equals(b)) continue;
        else return false;
      } catch {
      }
    }
    let [keys2, get3] = getters(a);
    const ka = keys2(a);
    const kb = keys2(b);
    if (ka.length !== kb.length) return false;
    for (let k of ka) {
      values3.push(get3(a, k), get3(b, k));
    }
  }
  return true;
}
function getters(object4) {
  if (object4 instanceof Map) {
    return [(x) => x.keys(), (x, y) => x.get(y)];
  } else {
    let extra = object4 instanceof globalThis.Error ? ["message"] : [];
    return [(x) => [...extra, ...Object.keys(x)], (x, y) => x[y]];
  }
}
function unequalDates(a, b) {
  return a instanceof Date && (a > b || a < b);
}
function unequalBuffers(a, b) {
  return !(a instanceof BitArray) && a.buffer instanceof ArrayBuffer && a.BYTES_PER_ELEMENT && !(a.byteLength === b.byteLength && a.every((n, i) => n === b[i]));
}
function unequalArrays(a, b) {
  return Array.isArray(a) && a.length !== b.length;
}
function unequalMaps(a, b) {
  return a instanceof Map && a.size !== b.size;
}
function unequalSets(a, b) {
  return a instanceof Set && (a.size != b.size || [...a].some((e) => !b.has(e)));
}
function unequalRegExps(a, b) {
  return a instanceof RegExp && (a.source !== b.source || a.flags !== b.flags);
}
function isObject(a) {
  return typeof a === "object" && a !== null;
}
function structurallyCompatibleObjects(a, b) {
  if (typeof a !== "object" && typeof b !== "object" && (!a || !b))
    return false;
  let nonstructural = [Promise, WeakSet, WeakMap, Function];
  if (nonstructural.some((c) => a instanceof c)) return false;
  return a.constructor === b.constructor;
}
function makeError(variant, file, module, line, fn, message, extra) {
  let error = new globalThis.Error(message);
  error.gleam_error = variant;
  error.file = file;
  error.module = module;
  error.line = line;
  error.function = fn;
  error.fn = fn;
  for (let k in extra) error[k] = extra[k];
  return error;
}

// public/build/dev/javascript/gleam_stdlib/dict.mjs
var referenceMap = /* @__PURE__ */ new WeakMap();
var tempDataView = /* @__PURE__ */ new DataView(
  /* @__PURE__ */ new ArrayBuffer(8)
);
var referenceUID = 0;
function hashByReference(o) {
  const known = referenceMap.get(o);
  if (known !== void 0) {
    return known;
  }
  const hash = referenceUID++;
  if (referenceUID === 2147483647) {
    referenceUID = 0;
  }
  referenceMap.set(o, hash);
  return hash;
}
function hashMerge(a, b) {
  return a ^ b + 2654435769 + (a << 6) + (a >> 2) | 0;
}
function hashString(s) {
  let hash = 0;
  const len = s.length;
  for (let i = 0; i < len; i++) {
    hash = Math.imul(31, hash) + s.charCodeAt(i) | 0;
  }
  return hash;
}
function hashNumber(n) {
  tempDataView.setFloat64(0, n);
  const i = tempDataView.getInt32(0);
  const j = tempDataView.getInt32(4);
  return Math.imul(73244475, i >> 16 ^ i) ^ j;
}
function hashBigInt(n) {
  return hashString(n.toString());
}
function hashObject(o) {
  const proto = Object.getPrototypeOf(o);
  if (proto !== null && typeof proto.hashCode === "function") {
    try {
      const code = o.hashCode(o);
      if (typeof code === "number") {
        return code;
      }
    } catch {
    }
  }
  if (o instanceof Promise || o instanceof WeakSet || o instanceof WeakMap) {
    return hashByReference(o);
  }
  if (o instanceof Date) {
    return hashNumber(o.getTime());
  }
  let h = 0;
  if (o instanceof ArrayBuffer) {
    o = new Uint8Array(o);
  }
  if (Array.isArray(o) || o instanceof Uint8Array) {
    for (let i = 0; i < o.length; i++) {
      h = Math.imul(31, h) + getHash(o[i]) | 0;
    }
  } else if (o instanceof Set) {
    o.forEach((v) => {
      h = h + getHash(v) | 0;
    });
  } else if (o instanceof Map) {
    o.forEach((v, k) => {
      h = h + hashMerge(getHash(v), getHash(k)) | 0;
    });
  } else {
    const keys2 = Object.keys(o);
    for (let i = 0; i < keys2.length; i++) {
      const k = keys2[i];
      const v = o[k];
      h = h + hashMerge(getHash(v), hashString(k)) | 0;
    }
  }
  return h;
}
function getHash(u) {
  if (u === null) return 1108378658;
  if (u === void 0) return 1108378659;
  if (u === true) return 1108378657;
  if (u === false) return 1108378656;
  switch (typeof u) {
    case "number":
      return hashNumber(u);
    case "string":
      return hashString(u);
    case "bigint":
      return hashBigInt(u);
    case "object":
      return hashObject(u);
    case "symbol":
      return hashByReference(u);
    case "function":
      return hashByReference(u);
    default:
      return 0;
  }
}
var Dict = class {
  constructor(size3, root2) {
    this.size = size3;
    this.root = root2;
  }
};
var bits = 5;
var mask = (1 << bits) - 1;
var noElementMarker = /* @__PURE__ */ Symbol();
var errorNil = /* @__PURE__ */ Result$Error(void 0);
function get(dict3, key) {
  const result = lookup(dict3.root, key, getHash(key));
  return result !== noElementMarker ? Result$Ok(result) : errorNil;
}
function lookup(node, key, hash) {
  for (let shift = 0; shift < 32; shift += bits) {
    const data = node.data;
    const bit = hashbit(hash, shift);
    if (node.nodemap & bit) {
      node = data[data.length - 1 - index(node.nodemap, bit)];
    } else if (node.datamap & bit) {
      const dataidx = Math.imul(index(node.datamap, bit), 2);
      return isEqual(key, data[dataidx]) ? data[dataidx + 1] : noElementMarker;
    } else {
      return noElementMarker;
    }
  }
  const overflow = node.data;
  for (let i = 0; i < overflow.length; i += 2) {
    if (isEqual(key, overflow[i])) {
      return overflow[i + 1];
    }
  }
  return noElementMarker;
}
function popcount(n) {
  n -= n >>> 1 & 1431655765;
  n = (n & 858993459) + (n >>> 2 & 858993459);
  return Math.imul(n + (n >>> 4) & 252645135, 16843009) >>> 24;
}
function index(bitmap, bit) {
  return popcount(bitmap & bit - 1);
}
function hashbit(hash, shift) {
  return 1 << (hash >>> shift & mask);
}

// public/build/dev/javascript/gleam_stdlib/gleam/option.mjs
var Some = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var Option$isSome = (value2) => value2 instanceof Some;
var Option$Some$0 = (value2) => value2[0];
var None = class extends CustomType {
};
var Option$None$const = new None();

// public/build/dev/javascript/gleam_stdlib/gleam/order.mjs
var Lt = class extends CustomType {
};
var Order$Lt$const = new Lt();
var Order$Lt = () => Order$Lt$const;
var Eq = class extends CustomType {
};
var Order$Eq$const = new Eq();
var Order$Eq = () => Order$Eq$const;
var Gt = class extends CustomType {
};
var Order$Gt$const = new Gt();
var Order$Gt = () => Order$Gt$const;

// public/build/dev/javascript/gleam_stdlib/gleam/list.mjs
var Ascending = class extends CustomType {
};
var Sorting$Ascending$const = new Ascending();
var Descending = class extends CustomType {
};
var Sorting$Descending$const = new Descending();
function reverse_and_prepend(loop$prefix, loop$suffix) {
  while (true) {
    let prefix = loop$prefix;
    let suffix = loop$suffix;
    if (prefix instanceof Empty) {
      return suffix;
    } else {
      let first$1 = prefix.head;
      let rest$1 = prefix.tail;
      loop$prefix = rest$1;
      loop$suffix = prepend(first$1, suffix);
    }
  }
}
function reverse(list4) {
  return reverse_and_prepend(list4, List$Empty$const);
}
function filter_loop(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list4 = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list4 instanceof Empty) {
      return reverse(acc);
    } else {
      let first$1 = list4.head;
      let rest$1 = list4.tail;
      let _block;
      let $ = fun(first$1);
      if ($) {
        _block = prepend(first$1, acc);
      } else {
        _block = acc;
      }
      let new_acc = _block;
      loop$list = rest$1;
      loop$fun = fun;
      loop$acc = new_acc;
    }
  }
}
function filter(list4, predicate) {
  return filter_loop(list4, predicate, List$Empty$const);
}
function map_loop(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list4 = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list4 instanceof Empty) {
      return reverse(acc);
    } else {
      let first$1 = list4.head;
      let rest$1 = list4.tail;
      loop$list = rest$1;
      loop$fun = fun;
      loop$acc = prepend(fun(first$1), acc);
    }
  }
}
function map2(list4, fun) {
  return map_loop(list4, fun, List$Empty$const);
}
function append_loop(loop$first, loop$second) {
  while (true) {
    let first = loop$first;
    let second = loop$second;
    if (first instanceof Empty) {
      return second;
    } else {
      let first$1 = first.head;
      let rest$1 = first.tail;
      loop$first = rest$1;
      loop$second = prepend(first$1, second);
    }
  }
}
function append(first, second) {
  return append_loop(reverse(first), second);
}
function flatten_loop(loop$lists, loop$acc) {
  while (true) {
    let lists = loop$lists;
    let acc = loop$acc;
    if (lists instanceof Empty) {
      return reverse(acc);
    } else {
      let list4 = lists.head;
      let further_lists = lists.tail;
      loop$lists = further_lists;
      loop$acc = reverse_and_prepend(list4, acc);
    }
  }
}
function flatten(lists) {
  return flatten_loop(lists, List$Empty$const);
}
function fold2(loop$list, loop$initial, loop$fun) {
  while (true) {
    let list4 = loop$list;
    let initial = loop$initial;
    let fun = loop$fun;
    if (list4 instanceof Empty) {
      return initial;
    } else {
      let first$1 = list4.head;
      let rest$1 = list4.tail;
      loop$list = rest$1;
      loop$initial = fun(initial, first$1);
      loop$fun = fun;
    }
  }
}
function merge_descendings(loop$list1, loop$list2, loop$compare, loop$acc) {
  while (true) {
    let list1 = loop$list1;
    let list22 = loop$list2;
    let compare3 = loop$compare;
    let acc = loop$acc;
    if (list1 instanceof Empty) {
      let list4 = list22;
      return reverse_and_prepend(list4, acc);
    } else if (list22 instanceof Empty) {
      let list4 = list1;
      return reverse_and_prepend(list4, acc);
    } else {
      let first1 = list1.head;
      let rest1 = list1.tail;
      let first2 = list22.head;
      let rest2 = list22.tail;
      let $ = compare3(first1, first2);
      if ($ instanceof Lt) {
        loop$list1 = list1;
        loop$list2 = rest2;
        loop$compare = compare3;
        loop$acc = prepend(first2, acc);
      } else if ($ instanceof Eq) {
        loop$list1 = rest1;
        loop$list2 = list22;
        loop$compare = compare3;
        loop$acc = prepend(first1, acc);
      } else {
        loop$list1 = rest1;
        loop$list2 = list22;
        loop$compare = compare3;
        loop$acc = prepend(first1, acc);
      }
    }
  }
}
function merge_descending_pairs(loop$sequences, loop$compare, loop$acc) {
  while (true) {
    let sequences2 = loop$sequences;
    let compare3 = loop$compare;
    let acc = loop$acc;
    if (sequences2 instanceof Empty) {
      return reverse(acc);
    } else {
      let $ = sequences2.tail;
      if ($ instanceof Empty) {
        let sequence = sequences2.head;
        return reverse(prepend(reverse(sequence), acc));
      } else {
        let descending1 = sequences2.head;
        let descending2 = $.head;
        let rest$1 = $.tail;
        let ascending = merge_descendings(
          descending1,
          descending2,
          compare3,
          List$Empty$const
        );
        loop$sequences = rest$1;
        loop$compare = compare3;
        loop$acc = prepend(ascending, acc);
      }
    }
  }
}
function merge_ascendings(loop$list1, loop$list2, loop$compare, loop$acc) {
  while (true) {
    let list1 = loop$list1;
    let list22 = loop$list2;
    let compare3 = loop$compare;
    let acc = loop$acc;
    if (list1 instanceof Empty) {
      let list4 = list22;
      return reverse_and_prepend(list4, acc);
    } else if (list22 instanceof Empty) {
      let list4 = list1;
      return reverse_and_prepend(list4, acc);
    } else {
      let first1 = list1.head;
      let rest1 = list1.tail;
      let first2 = list22.head;
      let rest2 = list22.tail;
      let $ = compare3(first1, first2);
      if ($ instanceof Lt) {
        loop$list1 = rest1;
        loop$list2 = list22;
        loop$compare = compare3;
        loop$acc = prepend(first1, acc);
      } else if ($ instanceof Eq) {
        loop$list1 = list1;
        loop$list2 = rest2;
        loop$compare = compare3;
        loop$acc = prepend(first2, acc);
      } else {
        loop$list1 = list1;
        loop$list2 = rest2;
        loop$compare = compare3;
        loop$acc = prepend(first2, acc);
      }
    }
  }
}
function merge_ascending_pairs(loop$sequences, loop$compare, loop$acc) {
  while (true) {
    let sequences2 = loop$sequences;
    let compare3 = loop$compare;
    let acc = loop$acc;
    if (sequences2 instanceof Empty) {
      return reverse(acc);
    } else {
      let $ = sequences2.tail;
      if ($ instanceof Empty) {
        let sequence = sequences2.head;
        return reverse(prepend(reverse(sequence), acc));
      } else {
        let ascending1 = sequences2.head;
        let ascending2 = $.head;
        let rest$1 = $.tail;
        let descending = merge_ascendings(
          ascending1,
          ascending2,
          compare3,
          List$Empty$const
        );
        loop$sequences = rest$1;
        loop$compare = compare3;
        loop$acc = prepend(descending, acc);
      }
    }
  }
}
function merge_all(loop$sequences, loop$direction, loop$compare) {
  while (true) {
    let sequences2 = loop$sequences;
    let direction = loop$direction;
    let compare3 = loop$compare;
    if (sequences2 instanceof Empty) {
      return sequences2;
    } else if (direction instanceof Ascending) {
      let $ = sequences2.tail;
      if ($ instanceof Empty) {
        let sequence = sequences2.head;
        return sequence;
      } else {
        let sequences$1 = merge_ascending_pairs(
          sequences2,
          compare3,
          List$Empty$const
        );
        loop$sequences = sequences$1;
        loop$direction = Sorting$Descending$const;
        loop$compare = compare3;
      }
    } else {
      let $ = sequences2.tail;
      if ($ instanceof Empty) {
        let sequence = sequences2.head;
        return reverse(sequence);
      } else {
        let sequences$1 = merge_descending_pairs(
          sequences2,
          compare3,
          List$Empty$const
        );
        loop$sequences = sequences$1;
        loop$direction = Sorting$Ascending$const;
        loop$compare = compare3;
      }
    }
  }
}
function sequences(loop$list, loop$compare, loop$growing, loop$direction, loop$prev, loop$acc) {
  while (true) {
    let list4 = loop$list;
    let compare3 = loop$compare;
    let growing = loop$growing;
    let direction = loop$direction;
    let prev = loop$prev;
    let acc = loop$acc;
    let growing$1 = prepend(prev, growing);
    if (list4 instanceof Empty) {
      if (direction instanceof Ascending) {
        return prepend(reverse(growing$1), acc);
      } else {
        return prepend(growing$1, acc);
      }
    } else {
      let new$1 = list4.head;
      let rest$1 = list4.tail;
      let $ = compare3(prev, new$1);
      if (direction instanceof Ascending) {
        if ($ instanceof Lt) {
          loop$list = rest$1;
          loop$compare = compare3;
          loop$growing = growing$1;
          loop$direction = direction;
          loop$prev = new$1;
          loop$acc = acc;
        } else if ($ instanceof Eq) {
          loop$list = rest$1;
          loop$compare = compare3;
          loop$growing = growing$1;
          loop$direction = direction;
          loop$prev = new$1;
          loop$acc = acc;
        } else {
          let _block;
          if (direction instanceof Ascending) {
            _block = prepend(reverse(growing$1), acc);
          } else {
            _block = prepend(growing$1, acc);
          }
          let acc$1 = _block;
          if (rest$1 instanceof Empty) {
            return prepend(toList([new$1]), acc$1);
          } else {
            let next = rest$1.head;
            let rest$2 = rest$1.tail;
            let _block$1;
            let $1 = compare3(new$1, next);
            if ($1 instanceof Lt) {
              _block$1 = Sorting$Ascending$const;
            } else if ($1 instanceof Eq) {
              _block$1 = Sorting$Ascending$const;
            } else {
              _block$1 = Sorting$Descending$const;
            }
            let direction$1 = _block$1;
            loop$list = rest$2;
            loop$compare = compare3;
            loop$growing = toList([new$1]);
            loop$direction = direction$1;
            loop$prev = next;
            loop$acc = acc$1;
          }
        }
      } else if ($ instanceof Lt) {
        let _block;
        if (direction instanceof Ascending) {
          _block = prepend(reverse(growing$1), acc);
        } else {
          _block = prepend(growing$1, acc);
        }
        let acc$1 = _block;
        if (rest$1 instanceof Empty) {
          return prepend(toList([new$1]), acc$1);
        } else {
          let next = rest$1.head;
          let rest$2 = rest$1.tail;
          let _block$1;
          let $1 = compare3(new$1, next);
          if ($1 instanceof Lt) {
            _block$1 = Sorting$Ascending$const;
          } else if ($1 instanceof Eq) {
            _block$1 = Sorting$Ascending$const;
          } else {
            _block$1 = Sorting$Descending$const;
          }
          let direction$1 = _block$1;
          loop$list = rest$2;
          loop$compare = compare3;
          loop$growing = toList([new$1]);
          loop$direction = direction$1;
          loop$prev = next;
          loop$acc = acc$1;
        }
      } else if ($ instanceof Eq) {
        let _block;
        if (direction instanceof Ascending) {
          _block = prepend(reverse(growing$1), acc);
        } else {
          _block = prepend(growing$1, acc);
        }
        let acc$1 = _block;
        if (rest$1 instanceof Empty) {
          return prepend(toList([new$1]), acc$1);
        } else {
          let next = rest$1.head;
          let rest$2 = rest$1.tail;
          let _block$1;
          let $1 = compare3(new$1, next);
          if ($1 instanceof Lt) {
            _block$1 = Sorting$Ascending$const;
          } else if ($1 instanceof Eq) {
            _block$1 = Sorting$Ascending$const;
          } else {
            _block$1 = Sorting$Descending$const;
          }
          let direction$1 = _block$1;
          loop$list = rest$2;
          loop$compare = compare3;
          loop$growing = toList([new$1]);
          loop$direction = direction$1;
          loop$prev = next;
          loop$acc = acc$1;
        }
      } else {
        loop$list = rest$1;
        loop$compare = compare3;
        loop$growing = growing$1;
        loop$direction = direction;
        loop$prev = new$1;
        loop$acc = acc;
      }
    }
  }
}
function sort(list4, compare3) {
  if (list4 instanceof Empty) {
    return list4;
  } else {
    let $ = list4.tail;
    if ($ instanceof Empty) {
      return list4;
    } else {
      let x = list4.head;
      let y = $.head;
      let rest$1 = $.tail;
      let _block;
      let $1 = compare3(x, y);
      if ($1 instanceof Lt) {
        _block = Sorting$Ascending$const;
      } else if ($1 instanceof Eq) {
        _block = Sorting$Ascending$const;
      } else {
        _block = Sorting$Descending$const;
      }
      let direction = _block;
      let sequences$1 = sequences(
        rest$1,
        compare3,
        toList([x]),
        direction,
        y,
        List$Empty$const
      );
      return merge_all(sequences$1, Sorting$Ascending$const, compare3);
    }
  }
}

// public/build/dev/javascript/gleam_stdlib/gleam/string_tree.mjs
var All = class extends CustomType {
};
var Direction$All$const = new All();

// public/build/dev/javascript/gleam_stdlib/gleam/string.mjs
var Leading = class extends CustomType {
};
var Direction$Leading$const = new Leading();
var Trailing = class extends CustomType {
};
var Direction$Trailing$const = new Trailing();
function split2(x, substring) {
  if (substring === "") {
    return graphemes(x);
  } else {
    let _pipe = x;
    let _pipe$1 = identity(_pipe);
    let _pipe$2 = split(_pipe$1, substring);
    return map2(_pipe$2, identity);
  }
}
function concat_loop(loop$strings, loop$accumulator) {
  while (true) {
    let strings = loop$strings;
    let accumulator = loop$accumulator;
    if (strings instanceof Empty) {
      return accumulator;
    } else {
      let string5 = strings.head;
      let strings$1 = strings.tail;
      loop$strings = strings$1;
      loop$accumulator = accumulator + string5;
    }
  }
}
function concat2(strings) {
  return concat_loop(strings, "");
}

// public/build/dev/javascript/gleam_stdlib/gleam/dynamic/decode.mjs
var DecodeError = class extends CustomType {
  constructor(expected, found, path) {
    super();
    this.expected = expected;
    this.found = found;
    this.path = path;
  }
};
var DecodeError$DecodeError = (expected, found, path) => new DecodeError(expected, found, path);
var Decoder = class extends CustomType {
  constructor(function$) {
    super();
    this.function = function$;
  }
};
var float2 = /* @__PURE__ */ new Decoder(decode_float);
var int2 = /* @__PURE__ */ new Decoder(decode_int);
var string2 = /* @__PURE__ */ new Decoder(decode_string);
function run(data, decoder4) {
  let $ = decoder4.function(data);
  let maybe_invalid_data = $[0];
  let errors = $[1];
  if (errors instanceof Empty) {
    return new Ok(maybe_invalid_data);
  } else {
    return new Error(errors);
  }
}
function run_dynamic_function(data, name, f) {
  let $ = f(data);
  if ($ instanceof Ok) {
    let data$1 = $[0];
    return [data$1, List$Empty$const];
  } else {
    let placeholder = $[0];
    return [
      placeholder,
      toList([new DecodeError(name, classify_dynamic(data), List$Empty$const)])
    ];
  }
}
function decode_float(data) {
  return run_dynamic_function(data, "Float", float);
}
function map3(decoder4, transformer) {
  return new Decoder(
    (d) => {
      let $ = decoder4.function(d);
      let data = $[0];
      let errors = $[1];
      return [transformer(data), errors];
    }
  );
}
function decode_int(data) {
  return run_dynamic_function(data, "Int", int);
}
function decode_string(data) {
  return run_dynamic_function(data, "String", string);
}
function run_decoders(loop$data, loop$failure, loop$decoders) {
  while (true) {
    let data = loop$data;
    let failure2 = loop$failure;
    let decoders = loop$decoders;
    if (decoders instanceof Empty) {
      return failure2;
    } else {
      let decoder4 = decoders.head;
      let decoders$1 = decoders.tail;
      let $ = decoder4.function(data);
      let layer = $;
      let errors = $[1];
      if (errors instanceof Empty) {
        return layer;
      } else {
        loop$data = data;
        loop$failure = failure2;
        loop$decoders = decoders$1;
      }
    }
  }
}
function one_of(first, alternatives) {
  return new Decoder(
    (dynamic_data) => {
      let $ = first.function(dynamic_data);
      let layer = $;
      let errors = $[1];
      if (errors instanceof Empty) {
        return layer;
      } else {
        return run_decoders(dynamic_data, layer, alternatives);
      }
    }
  );
}
function path_segment_to_string(key) {
  let decoder4 = one_of(
    string2,
    toList([
      (() => {
        let _pipe = int2;
        return map3(_pipe, to_string);
      })(),
      (() => {
        let _pipe = float2;
        return map3(_pipe, float_to_string);
      })()
    ])
  );
  let $ = run(key, decoder4);
  if ($ instanceof Ok) {
    let key$1 = $[0];
    return key$1;
  } else {
    return "<" + classify_dynamic(key) + ">";
  }
}
function push_path(layer, path) {
  let path$1 = map2(
    path,
    (key) => {
      let _pipe = key;
      let _pipe$1 = identity(_pipe);
      return path_segment_to_string(_pipe$1);
    }
  );
  let errors = map2(
    layer[1],
    (error) => {
      return new DecodeError(
        error.expected,
        error.found,
        append(path$1, error.path)
      );
    }
  );
  return [layer[0], errors];
}
function list2(inner) {
  return new Decoder(
    (data) => {
      return list(
        data,
        inner.function,
        (p, k) => {
          return push_path(p, toList([k]));
        },
        0,
        List$Empty$const
      );
    }
  );
}
function index3(loop$path, loop$position, loop$inner, loop$data, loop$handle_miss) {
  while (true) {
    let path = loop$path;
    let position = loop$position;
    let inner = loop$inner;
    let data = loop$data;
    let handle_miss = loop$handle_miss;
    if (path instanceof Empty) {
      let _pipe = data;
      let _pipe$1 = inner(_pipe);
      return push_path(_pipe$1, reverse(position));
    } else {
      let key = path.head;
      let path$1 = path.tail;
      let $ = index2(data, key);
      if ($ instanceof Ok) {
        let $1 = $[0];
        if ($1 instanceof Some) {
          let data$1 = $1[0];
          loop$path = path$1;
          loop$position = prepend(key, position);
          loop$inner = inner;
          loop$data = data$1;
          loop$handle_miss = handle_miss;
        } else {
          return handle_miss(data, prepend(key, position));
        }
      } else {
        let kind = $[0];
        let $1 = inner(data);
        let default$ = $1[0];
        let _pipe = [
          default$,
          toList([
            new DecodeError(kind, classify_dynamic(data), List$Empty$const)
          ])
        ];
        return push_path(_pipe, reverse(position));
      }
    }
  }
}
function subfield(field_path, field_decoder, next) {
  return new Decoder(
    (data) => {
      let $ = index3(
        field_path,
        List$Empty$const,
        field_decoder.function,
        data,
        (data2, position) => {
          let $12 = field_decoder.function(data2);
          let default$ = $12[0];
          let _pipe = [
            default$,
            toList([new DecodeError("Field", "Nothing", List$Empty$const)])
          ];
          return push_path(_pipe, reverse(position));
        }
      );
      let out = $[0];
      let errors1 = $[1];
      let $1 = next(out).function(data);
      let out$1 = $1[0];
      let errors2 = $1[1];
      return [out$1, append(errors1, errors2)];
    }
  );
}
function at(path, inner) {
  return new Decoder(
    (data) => {
      return index3(
        path,
        List$Empty$const,
        inner.function,
        data,
        (data2, position) => {
          let $ = inner.function(data2);
          let default$ = $[0];
          let _pipe = [
            default$,
            toList([new DecodeError("Field", "Nothing", List$Empty$const)])
          ];
          return push_path(_pipe, reverse(position));
        }
      );
    }
  );
}
function success(data) {
  return new Decoder((_) => {
    return [data, List$Empty$const];
  });
}
function field(field_name, field_decoder, next) {
  return subfield(toList([field_name]), field_decoder, next);
}
function optional(inner) {
  return new Decoder(
    (data) => {
      let $ = is_null(data);
      if ($) {
        return [Option$None$const, List$Empty$const];
      } else {
        let $1 = inner.function(data);
        let data$1 = $1[0];
        let errors = $1[1];
        return [new Some(data$1), errors];
      }
    }
  );
}
function then$(decoder4, next) {
  return new Decoder(
    (dynamic_data) => {
      let $ = decoder4.function(dynamic_data);
      let data = $[0];
      let errors = $[1];
      let decoder$1 = next(data);
      let $1 = decoder$1.function(dynamic_data);
      let layer = $1;
      let data$1 = $1[0];
      if (errors instanceof Empty) {
        return layer;
      } else {
        return [data$1, errors];
      }
    }
  );
}

// public/build/dev/javascript/gleam_stdlib/gleam_stdlib.mjs
function identity(x) {
  return x;
}
function to_string(term) {
  return term.toString();
}
function graphemes(string5) {
  const iterator = graphemes_iterator(string5);
  if (iterator) {
    return arrayToList(Array.from(iterator).map((item) => item.segment));
  } else {
    return arrayToList(string5.match(/./gsu));
  }
}
var segmenter = void 0;
function graphemes_iterator(string5) {
  if (globalThis.Intl && Intl.Segmenter) {
    segmenter ||= new Intl.Segmenter();
    return segmenter.segment(string5)[Symbol.iterator]();
  }
}
function split(xs, pattern) {
  return arrayToList(xs.split(pattern));
}
function starts_with(haystack, needle) {
  return haystack.startsWith(needle);
}
var unicode_whitespaces = [
  " ",
  // Space
  "	",
  // Horizontal tab
  "\n",
  // Line feed
  "\v",
  // Vertical tab
  "\f",
  // Form feed
  "\r",
  // Carriage return
  "\x85",
  // Next line
  "\u2028",
  // Line separator
  "\u2029"
  // Paragraph separator
].join("");
var trim_start_regex = /* @__PURE__ */ new RegExp(
  `^[${unicode_whitespaces}]*`
);
var trim_end_regex = /* @__PURE__ */ new RegExp(`[${unicode_whitespaces}]*$`);
function classify_dynamic(data) {
  if (typeof data === "string") {
    return "String";
  } else if (typeof data === "boolean") {
    return "Bool";
  } else if (isResult(data)) {
    return "Result";
  } else if (isList(data)) {
    return "List";
  } else if (data instanceof BitArray) {
    return "BitArray";
  } else if (data instanceof Dict) {
    return "Dict";
  } else if (Number.isInteger(data)) {
    return "Int";
  } else if (Array.isArray(data)) {
    return `Array`;
  } else if (typeof data === "number") {
    return "Float";
  } else if (data === null) {
    return "Nil";
  } else if (data === void 0) {
    return "Nil";
  } else {
    const type = typeof data;
    return type.charAt(0).toUpperCase() + type.slice(1);
  }
}
var MIN_I32 = -(2 ** 31);
var MAX_I32 = 2 ** 31 - 1;
var U32 = 2 ** 32;
var MAX_SAFE = Number.MAX_SAFE_INTEGER;
var MIN_SAFE = Number.MIN_SAFE_INTEGER;
function float_to_string(float3) {
  const string5 = float3.toString().replace("+", "");
  if (string5.indexOf(".") >= 0) {
    return string5;
  } else {
    const index4 = string5.indexOf("e");
    if (index4 >= 0) {
      return string5.slice(0, index4) + ".0" + string5.slice(index4);
    } else {
      return string5 + ".0";
    }
  }
}
function index2(data, key) {
  if (data instanceof Dict) {
    const result = get(data, key);
    return Result$Ok(result.isOk() ? new Some(result[0]) : new None());
  }
  if (data instanceof WeakMap || data instanceof Map) {
    const token = {};
    const entry = data.get(key, token);
    if (entry === token) return Result$Ok(new None());
    return Result$Ok(new Some(entry));
  }
  const key_is_int = Number.isInteger(key);
  if (key_is_int && key >= 0 && key < 8 && isList(data)) {
    let i = 0;
    for (const value2 of data) {
      if (i === key) return Result$Ok(new Some(value2));
      i++;
    }
    return Result$Error("Indexable");
  }
  if (key_is_int && Array.isArray(data) || data && typeof data === "object" || data && Object.getPrototypeOf(data) === Object.prototype) {
    if (key in data) return Result$Ok(new Some(data[key]));
    return Result$Ok(new None());
  }
  return Result$Error(key_is_int ? "Indexable" : "Dict");
}
function list(data, decode3, pushPath, index4, emptyList) {
  if (!(isList(data) || Array.isArray(data))) {
    const error = DecodeError$DecodeError("List", classify_dynamic(data), emptyList);
    return [emptyList, arrayToList([error])];
  }
  const decoded = [];
  for (const element5 of data) {
    const layer = decode3(element5);
    const [out, errors] = layer;
    if (List$isNonEmpty(errors)) {
      const [_, errors2] = pushPath(layer, index4.toString());
      return [emptyList, errors2];
    }
    decoded.push(out);
    index4++;
  }
  return [arrayToList(decoded), emptyList];
}
function float(data) {
  if (typeof data === "number") return Result$Ok(data);
  return Result$Error(0);
}
function int(data) {
  if (Number.isInteger(data)) return Result$Ok(data);
  return Result$Error(0);
}
function string(data) {
  if (typeof data === "string") return Result$Ok(data);
  return Result$Error("");
}
function is_null(data) {
  return data === null || data === void 0;
}
function arrayToList(array3) {
  let list4 = List$Empty();
  let i = array3.length;
  while (i--) {
    list4 = List$NonEmpty(array3[i], list4);
  }
  return list4;
}
function isList(data) {
  return List$isEmpty(data) || List$isNonEmpty(data);
}
function isResult(data) {
  return Result$isOk(data) || Result$isError(data);
}

// public/build/dev/javascript/gleam_erlang/gleam/erlang/process.mjs
var Normal = class extends CustomType {
};
var ExitReason$Normal$const = new Normal();
var Killed = class extends CustomType {
};
var ExitReason$Killed$const = new Killed();
var Anything = class extends CustomType {
};
var AnythingSelectorTag$Anything$const = new Anything();
var Process = class extends CustomType {
};
var ProcessMonitorFlag$Process$const = new Process();
var TimerNotFound = class extends CustomType {
};
var Cancelled$TimerNotFound$const = new TimerNotFound();
var Kill = class extends CustomType {
};
var KillFlag$Kill$const = new Kill();

// public/build/dev/javascript/gleam_otp/gleam/otp/system.mjs
var Running = class extends CustomType {
};
var Mode$Running$const = new Running();
var Suspended = class extends CustomType {
};
var Mode$Suspended$const = new Suspended();
var NoDebug = class extends CustomType {
};
var DebugOption$NoDebug$const = new NoDebug();

// public/build/dev/javascript/gleam_otp/gleam/otp/actor.mjs
var InitTimeout = class extends CustomType {
};
var StartError$InitTimeout$const = new InitTimeout();

// public/build/dev/javascript/gleam_otp/gleam/otp/supervision.mjs
var Permanent = class extends CustomType {
};
var Restart$Permanent$const = new Permanent();
var Transient = class extends CustomType {
};
var Restart$Transient$const = new Transient();
var Temporary = class extends CustomType {
};
var Restart$Temporary$const = new Temporary();
var Supervisor = class extends CustomType {
};
var ChildType$Supervisor$const = new Supervisor();

// public/build/dev/javascript/gleam_otp/gleam/otp/factory_supervisor.mjs
var SimpleOneForOne = class extends CustomType {
};
var Strategy$SimpleOneForOne$const = new SimpleOneForOne();

// public/build/dev/javascript/gleam_stdlib/gleam/function.mjs
function identity2(x) {
  return x;
}

// public/build/dev/javascript/gleam_json/gleam_json_ffi.mjs
function object(entries) {
  return Object.fromEntries(entries);
}
function identity3(x) {
  return x;
}
function do_null() {
  return null;
}

// public/build/dev/javascript/gleam_json/gleam/json.mjs
var UnexpectedEndOfInput = class extends CustomType {
};
var DecodeError$UnexpectedEndOfInput$const = new UnexpectedEndOfInput();
function string3(input) {
  return identity3(input);
}
function bool(input) {
  return identity3(input);
}
function null$() {
  return do_null();
}
function object2(entries) {
  return object(entries);
}

// public/build/dev/javascript/houdini/houdini.ffi.mjs
function escape(string5) {
  return string5.replaceAll(/[><&"']/g, (replaced) => {
    switch (replaced) {
      case ">":
        return "&gt;";
      case "<":
        return "&lt;";
      case "'":
        return "&#39;";
      case "&":
        return "&amp;";
      case '"':
        return "&quot;";
      default:
        return replaced;
    }
  });
}

// public/build/dev/javascript/lustre/lustre/internals/constants.mjs
var empty_list = List$Empty$const;
var error_nil = /* @__PURE__ */ new Error(void 0);
function singleton_list(item) {
  return prepend(item, empty_list);
}

// public/build/dev/javascript/lustre/lustre/vdom/vattr.ffi.mjs
var GT = /* @__PURE__ */ Order$Gt();
var LT = /* @__PURE__ */ Order$Lt();
var EQ = /* @__PURE__ */ Order$Eq();
function compare2(a, b) {
  if (a.name === b.name) {
    return EQ;
  } else if (a.name < b.name) {
    return LT;
  } else {
    return GT;
  }
}

// public/build/dev/javascript/lustre/lustre/vdom/vattr.mjs
var Attribute = class extends CustomType {
  constructor(kind, name, value2) {
    super();
    this.kind = kind;
    this.name = name;
    this.value = value2;
  }
};
var Property = class extends CustomType {
  constructor(kind, name, value2) {
    super();
    this.kind = kind;
    this.name = name;
    this.value = value2;
  }
};
var Event2 = class extends CustomType {
  constructor(kind, name, handler, include, prevent_default, stop_propagation, debounce, throttle) {
    super();
    this.kind = kind;
    this.name = name;
    this.handler = handler;
    this.include = include;
    this.prevent_default = prevent_default;
    this.stop_propagation = stop_propagation;
    this.debounce = debounce;
    this.throttle = throttle;
  }
};
var Handler = class extends CustomType {
  constructor(prevent_default, stop_propagation, message) {
    super();
    this.prevent_default = prevent_default;
    this.stop_propagation = stop_propagation;
    this.message = message;
  }
};
var Never = class extends CustomType {
  constructor(kind) {
    super();
    this.kind = kind;
  }
};
var attribute_kind = 0;
var property_kind = 1;
var event_kind = 2;
var never_kind = 0;
var never = /* @__PURE__ */ new Never(never_kind);
var always_kind = 2;
function attribute(name, value2) {
  return new Attribute(attribute_kind, name, value2);
}
function property(name, value2) {
  return new Property(property_kind, name, value2);
}
function event(name, handler, include, prevent_default, stop_propagation, debounce, throttle) {
  return new Event2(
    event_kind,
    name,
    handler,
    include,
    prevent_default,
    stop_propagation,
    debounce,
    throttle
  );
}
function merge(loop$attributes, loop$merged) {
  while (true) {
    let attributes = loop$attributes;
    let merged = loop$merged;
    if (attributes instanceof Empty) {
      return merged;
    } else {
      let $ = attributes.head;
      if ($ instanceof Attribute) {
        let $1 = $.name;
        if ($1 === "") {
          let rest = attributes.tail;
          loop$attributes = rest;
          loop$merged = merged;
        } else if ($1 === "class") {
          let $2 = $.value;
          if ($2 === "") {
            let rest = attributes.tail;
            loop$attributes = rest;
            loop$merged = merged;
          } else {
            let $3 = attributes.tail;
            if ($3 instanceof Empty) {
              let attribute$1 = $;
              let rest = $3;
              loop$attributes = rest;
              loop$merged = prepend(attribute$1, merged);
            } else {
              let $4 = $3.head;
              if ($4 instanceof Attribute) {
                let $5 = $4.name;
                if ($5 === "class") {
                  let kind = $.kind;
                  let class1 = $2;
                  let rest = $3.tail;
                  let class2 = $4.value;
                  let value2 = class1 + " " + class2;
                  let attribute$1 = new Attribute(kind, "class", value2);
                  loop$attributes = prepend(attribute$1, rest);
                  loop$merged = merged;
                } else {
                  let attribute$1 = $;
                  let rest = $3;
                  loop$attributes = rest;
                  loop$merged = prepend(attribute$1, merged);
                }
              } else {
                let attribute$1 = $;
                let rest = $3;
                loop$attributes = rest;
                loop$merged = prepend(attribute$1, merged);
              }
            }
          }
        } else if ($1 === "style") {
          let $2 = $.value;
          if ($2 === "") {
            let rest = attributes.tail;
            loop$attributes = rest;
            loop$merged = merged;
          } else {
            let $3 = attributes.tail;
            if ($3 instanceof Empty) {
              let attribute$1 = $;
              let rest = $3;
              loop$attributes = rest;
              loop$merged = prepend(attribute$1, merged);
            } else {
              let $4 = $3.head;
              if ($4 instanceof Attribute) {
                let $5 = $4.name;
                if ($5 === "style") {
                  let kind = $.kind;
                  let style1 = $2;
                  let rest = $3.tail;
                  let style2 = $4.value;
                  let value2 = style1 + ";" + style2;
                  let attribute$1 = new Attribute(kind, "style", value2);
                  loop$attributes = prepend(attribute$1, rest);
                  loop$merged = merged;
                } else {
                  let attribute$1 = $;
                  let rest = $3;
                  loop$attributes = rest;
                  loop$merged = prepend(attribute$1, merged);
                }
              } else {
                let attribute$1 = $;
                let rest = $3;
                loop$attributes = rest;
                loop$merged = prepend(attribute$1, merged);
              }
            }
          }
        } else {
          let attribute$1 = $;
          let rest = attributes.tail;
          loop$attributes = rest;
          loop$merged = prepend(attribute$1, merged);
        }
      } else {
        let attribute$1 = $;
        let rest = attributes.tail;
        loop$attributes = rest;
        loop$merged = prepend(attribute$1, merged);
      }
    }
  }
}
function prepare(attributes) {
  if (attributes instanceof Empty) {
    return attributes;
  } else {
    let $ = attributes.tail;
    if ($ instanceof Empty) {
      return attributes;
    } else {
      let _pipe = attributes;
      let _pipe$1 = sort(_pipe, (a, b) => {
        return compare2(b, a);
      });
      return merge(_pipe$1, empty_list);
    }
  }
}

// public/build/dev/javascript/lustre/lustre/attribute.mjs
function attribute2(name, value2) {
  return attribute(name, value2);
}
function property2(name, value2) {
  return property(name, value2);
}
function boolean_attribute(name, value2) {
  if (value2) {
    return attribute2(name, "");
  } else {
    return property2(name, bool(false));
  }
}
function disabled(is_disabled) {
  return boolean_attribute("disabled", is_disabled);
}
function value(control_value) {
  return attribute2("value", control_value);
}

// public/build/dev/javascript/lustre/lustre/effect.mjs
var Effect = class extends CustomType {
  constructor(synchronous, before_paint2, after_paint) {
    super();
    this.synchronous = synchronous;
    this.before_paint = before_paint2;
    this.after_paint = after_paint;
  }
};
var empty = /* @__PURE__ */ new Effect(
  empty_list,
  empty_list,
  empty_list
);
function none() {
  return empty;
}
function from2(effect) {
  let task = (actions) => {
    let dispatch2 = actions.dispatch;
    return effect(dispatch2);
  };
  return new Effect(
    singleton_list(task),
    empty.before_paint,
    empty.after_paint
  );
}
function event2(name, data) {
  let task = (actions) => {
    return actions.emit(name, data);
  };
  return new Effect(
    singleton_list(task),
    empty.before_paint,
    empty.after_paint
  );
}

// public/build/dev/javascript/lustre/lustre/internals/mutable_map.ffi.mjs
function empty2() {
  return null;
}
function get2(map7, key) {
  return map7?.get(key);
}
function get_or_compute(map7, key, compute) {
  return map7?.get(key) ?? compute();
}
function has_key(map7, key) {
  return map7 && map7.has(key);
}
function insert2(map7, key, value2) {
  map7 ??= /* @__PURE__ */ new Map();
  map7.set(key, value2);
  return map7;
}
function remove(map7, key) {
  map7?.delete(key);
  return map7;
}

// public/build/dev/javascript/lustre/lustre/internals/ref.ffi.mjs
function sameValueZero(x, y) {
  if (typeof x === "number" && typeof y === "number") {
    return x === y || x !== x && y !== y;
  }
  return x === y;
}

// public/build/dev/javascript/lustre/lustre/internals/ref.mjs
function equal_lists(loop$xs, loop$ys) {
  while (true) {
    let xs = loop$xs;
    let ys = loop$ys;
    if (xs instanceof Empty) {
      if (ys instanceof Empty) {
        return true;
      } else {
        return false;
      }
    } else if (ys instanceof Empty) {
      return false;
    } else {
      let x = xs.head;
      let xs$1 = xs.tail;
      let y = ys.head;
      let ys$1 = ys.tail;
      let $ = sameValueZero(x, y);
      if ($) {
        loop$xs = xs$1;
        loop$ys = ys$1;
      } else {
        return $;
      }
    }
  }
}

// public/build/dev/javascript/lustre/lustre/vdom/vnode.mjs
var Fragment = class extends CustomType {
  constructor(kind, key, children, keyed_children) {
    super();
    this.kind = kind;
    this.key = key;
    this.children = children;
    this.keyed_children = keyed_children;
  }
};
var Element = class extends CustomType {
  constructor(kind, key, namespace, tag, attributes, children, keyed_children, self_closing, void$) {
    super();
    this.kind = kind;
    this.key = key;
    this.namespace = namespace;
    this.tag = tag;
    this.attributes = attributes;
    this.children = children;
    this.keyed_children = keyed_children;
    this.self_closing = self_closing;
    this.void = void$;
  }
};
var Text = class extends CustomType {
  constructor(kind, key, content) {
    super();
    this.kind = kind;
    this.key = key;
    this.content = content;
  }
};
var UnsafeInnerHtml = class extends CustomType {
  constructor(kind, key, namespace, tag, attributes, inner_html) {
    super();
    this.kind = kind;
    this.key = key;
    this.namespace = namespace;
    this.tag = tag;
    this.attributes = attributes;
    this.inner_html = inner_html;
  }
};
var Map2 = class extends CustomType {
  constructor(kind, key, mapper, child2) {
    super();
    this.kind = kind;
    this.key = key;
    this.mapper = mapper;
    this.child = child2;
  }
};
var Memo = class extends CustomType {
  constructor(kind, key, dependencies, view3) {
    super();
    this.kind = kind;
    this.key = key;
    this.dependencies = dependencies;
    this.view = view3;
  }
};
var fragment_kind = 0;
var element_kind = 1;
var text_kind = 2;
var unsafe_inner_html_kind = 3;
var map_kind = 4;
var memo_kind = 5;
function fragment(key, children, keyed_children) {
  return new Fragment(fragment_kind, key, children, keyed_children);
}
function element(key, namespace, tag, attributes, children, keyed_children, self_closing, void$) {
  return new Element(
    element_kind,
    key,
    namespace,
    tag,
    prepare(attributes),
    children,
    keyed_children,
    self_closing,
    void$
  );
}
function is_void_html_element(tag, namespace) {
  if (namespace === "") {
    if (tag === "area") {
      return true;
    } else if (tag === "base") {
      return true;
    } else if (tag === "br") {
      return true;
    } else if (tag === "col") {
      return true;
    } else if (tag === "embed") {
      return true;
    } else if (tag === "hr") {
      return true;
    } else if (tag === "img") {
      return true;
    } else if (tag === "input") {
      return true;
    } else if (tag === "link") {
      return true;
    } else if (tag === "meta") {
      return true;
    } else if (tag === "param") {
      return true;
    } else if (tag === "source") {
      return true;
    } else if (tag === "track") {
      return true;
    } else if (tag === "wbr") {
      return true;
    } else {
      return false;
    }
  } else {
    return false;
  }
}
function text(key, content) {
  return new Text(text_kind, key, content);
}
function map4(element5, mapper) {
  if (element5 instanceof Map2) {
    let child_mapper = element5.mapper;
    return new Map2(
      map_kind,
      element5.key,
      (handler) => {
        return identity2(mapper)(child_mapper(handler));
      },
      identity2(element5.child)
    );
  } else {
    return new Map2(map_kind, element5.key, identity2(mapper), identity2(element5));
  }
}
function memo(key, dependencies, view3) {
  return new Memo(memo_kind, key, dependencies, view3);
}
function to_keyed(key, node) {
  if (node instanceof Fragment) {
    return new Fragment(node.kind, key, node.children, node.keyed_children);
  } else if (node instanceof Element) {
    return new Element(
      node.kind,
      key,
      node.namespace,
      node.tag,
      node.attributes,
      node.children,
      node.keyed_children,
      node.self_closing,
      node.void
    );
  } else if (node instanceof Text) {
    return new Text(node.kind, key, node.content);
  } else if (node instanceof UnsafeInnerHtml) {
    return new UnsafeInnerHtml(
      node.kind,
      key,
      node.namespace,
      node.tag,
      node.attributes,
      node.inner_html
    );
  } else if (node instanceof Map2) {
    let child2 = node.child;
    return new Map2(node.kind, key, node.mapper, to_keyed(key, child2));
  } else {
    let view3 = node.view;
    return new Memo(
      node.kind,
      key,
      node.dependencies,
      () => {
        return to_keyed(key, view3());
      }
    );
  }
}

// public/build/dev/javascript/lustre/lustre/element.mjs
var Html = class extends CustomType {
};
var DocumentType$Html$const = new Html();
var HeadOnly = class extends CustomType {
};
var DocumentType$HeadOnly$const = new HeadOnly();
var BodyOnly = class extends CustomType {
};
var DocumentType$BodyOnly$const = new BodyOnly();
var HeadAndBody = class extends CustomType {
};
var DocumentType$HeadAndBody$const = new HeadAndBody();
var Other = class extends CustomType {
};
var DocumentType$Other$const = new Other();
function element2(tag, attributes, children) {
  return element(
    "",
    "",
    tag,
    attributes,
    children,
    empty2(),
    false,
    is_void_html_element(tag, "")
  );
}
function text2(content) {
  return text("", content);
}
function none2() {
  return text("", "");
}
function memo2(dependencies, view3) {
  return memo("", dependencies, view3);
}
function ref(value2) {
  return identity2(value2);
}
function map5(element5, f) {
  return map4(element5, f);
}

// public/build/dev/javascript/lustre/lustre/vdom/patch.mjs
var Patch = class extends CustomType {
  constructor(index4, path, removed, changes, children) {
    super();
    this.index = index4;
    this.path = path;
    this.removed = removed;
    this.changes = changes;
    this.children = children;
  }
};
var ReplaceText = class extends CustomType {
  constructor(kind, content) {
    super();
    this.kind = kind;
    this.content = content;
  }
};
var ReplaceInnerHtml = class extends CustomType {
  constructor(kind, inner_html) {
    super();
    this.kind = kind;
    this.inner_html = inner_html;
  }
};
var Update = class extends CustomType {
  constructor(kind, added, removed) {
    super();
    this.kind = kind;
    this.added = added;
    this.removed = removed;
  }
};
var Move = class extends CustomType {
  constructor(kind, key, before) {
    super();
    this.kind = kind;
    this.key = key;
    this.before = before;
  }
};
var Replace = class extends CustomType {
  constructor(kind, index4, with$) {
    super();
    this.kind = kind;
    this.index = index4;
    this.with = with$;
  }
};
var Remove = class extends CustomType {
  constructor(kind, index4) {
    super();
    this.kind = kind;
    this.index = index4;
  }
};
var Insert = class extends CustomType {
  constructor(kind, children, before) {
    super();
    this.kind = kind;
    this.children = children;
    this.before = before;
  }
};
var replace_text_kind = 0;
var replace_inner_html_kind = 1;
var update_kind = 2;
var move_kind = 3;
var remove_kind = 4;
var replace_kind = 5;
var insert_kind = 6;
function new$3(index4, removed, changes, children) {
  return new Patch(index4, empty_list, removed, changes, children);
}
function replace_text(content) {
  return new ReplaceText(replace_text_kind, content);
}
function replace_inner_html(inner_html) {
  return new ReplaceInnerHtml(replace_inner_html_kind, inner_html);
}
function update(added, removed) {
  return new Update(update_kind, added, removed);
}
function move(key, before) {
  return new Move(move_kind, key, before);
}
function remove2(index4) {
  return new Remove(remove_kind, index4);
}
function replace2(index4, with$) {
  return new Replace(replace_kind, index4, with$);
}
function insert3(children, before) {
  return new Insert(insert_kind, children, before);
}
function add_parent(child2, index4) {
  return new Patch(
    index4,
    prepend(child2.index, child2.path),
    child2.removed,
    child2.changes,
    child2.children
  );
}

// public/build/dev/javascript/lustre/lustre/vdom/path.mjs
var Root = class extends CustomType {
};
var Path$Root$const = new Root();
var Key = class extends CustomType {
  constructor(key, parent) {
    super();
    this.key = key;
    this.parent = parent;
  }
};
var Index = class extends CustomType {
  constructor(index4, parent) {
    super();
    this.index = index4;
    this.parent = parent;
  }
};
var Subtree = class extends CustomType {
  constructor(parent) {
    super();
    this.parent = parent;
  }
};
var separator_subtree = "\r";
var separator_element = "	";
var separator_event = "\n";
var root = Path$Root$const;
function finish_to_string(acc) {
  if (acc instanceof Empty) {
    return "";
  } else {
    let segments = acc.tail;
    return concat2(segments);
  }
}
function do_to_string(loop$full, loop$path, loop$acc) {
  while (true) {
    let full = loop$full;
    let path = loop$path;
    let acc = loop$acc;
    if (path instanceof Root) {
      return finish_to_string(acc);
    } else if (path instanceof Key) {
      let key = path.key;
      let parent = path.parent;
      loop$full = full;
      loop$path = parent;
      loop$acc = prepend(separator_element, prepend(key, acc));
    } else if (path instanceof Index) {
      let index4 = path.index;
      let parent = path.parent;
      let acc$1 = prepend(
        separator_element,
        prepend(to_string(index4), acc)
      );
      loop$full = full;
      loop$path = parent;
      loop$acc = acc$1;
    } else if (!full) {
      return finish_to_string(acc);
    } else {
      let parent = path.parent;
      if (acc instanceof Empty) {
        loop$full = full;
        loop$path = parent;
        loop$acc = acc;
      } else {
        let acc$1 = acc.tail;
        loop$full = full;
        loop$path = parent;
        loop$acc = prepend(separator_subtree, acc$1);
      }
    }
  }
}
function to_string3(path) {
  return do_to_string(true, path, empty_list);
}
function do_matches(loop$path, loop$candidates) {
  while (true) {
    let path = loop$path;
    let candidates = loop$candidates;
    if (candidates instanceof Empty) {
      return false;
    } else {
      let candidate = candidates.head;
      let rest = candidates.tail;
      let $ = starts_with(path, candidate);
      if ($) {
        return $;
      } else {
        loop$path = path;
        loop$candidates = rest;
      }
    }
  }
}
function matches(path, candidates) {
  if (candidates instanceof Empty) {
    return false;
  } else {
    return do_matches(to_string3(path), candidates);
  }
}
function split_subtree_path(path) {
  return split2(path, separator_subtree);
}
function add2(parent, index4, key) {
  if (key === "") {
    return new Index(index4, parent);
  } else {
    return new Key(key, parent);
  }
}
function subtree(path) {
  return new Subtree(path);
}
function event3(path, event4) {
  return do_to_string(
    false,
    path,
    prepend(separator_event, prepend(event4, empty_list))
  );
}
function child(path) {
  return do_to_string(false, path, empty_list);
}

// public/build/dev/javascript/lustre/lustre/vdom/cache.mjs
var Cache = class extends CustomType {
  constructor(events2, vdoms, old_vdoms, dispatched_paths, next_dispatched_paths) {
    super();
    this.events = events2;
    this.vdoms = vdoms;
    this.old_vdoms = old_vdoms;
    this.dispatched_paths = dispatched_paths;
    this.next_dispatched_paths = next_dispatched_paths;
  }
};
var Events = class extends CustomType {
  constructor(handlers, children) {
    super();
    this.handlers = handlers;
    this.children = children;
  }
};
var Child = class extends CustomType {
  constructor(mapper, events2) {
    super();
    this.mapper = mapper;
    this.events = events2;
  }
};
var AddedChildren = class extends CustomType {
  constructor(handlers, children, vdoms) {
    super();
    this.handlers = handlers;
    this.children = children;
    this.vdoms = vdoms;
  }
};
var DecodedEvent = class extends CustomType {
  constructor(path, handler) {
    super();
    this.path = path;
    this.handler = handler;
  }
};
var DispatchedEvent = class extends CustomType {
  constructor(path) {
    super();
    this.path = path;
  }
};
function compose_mapper(mapper, child_mapper) {
  return (message) => {
    return mapper(child_mapper(message));
  };
}
function new_events() {
  return new Events(empty2(), empty2());
}
function new$4() {
  return new Cache(
    new_events(),
    empty2(),
    empty2(),
    empty_list,
    empty_list
  );
}
function do_add_event(handlers, path, name, handler) {
  return insert2(handlers, event3(path, name), handler);
}
function add_attributes(handlers, path, attributes) {
  return fold2(
    attributes,
    handlers,
    (events2, attribute3) => {
      if (attribute3 instanceof Event2) {
        let name = attribute3.name;
        let handler = attribute3.handler;
        return do_add_event(events2, path, name, handler);
      } else {
        return events2;
      }
    }
  );
}
function do_add_children(loop$handlers, loop$children, loop$vdoms, loop$parent, loop$child_index, loop$nodes) {
  while (true) {
    let handlers = loop$handlers;
    let children = loop$children;
    let vdoms = loop$vdoms;
    let parent = loop$parent;
    let child_index = loop$child_index;
    let nodes = loop$nodes;
    let next = child_index + 1;
    if (nodes instanceof Empty) {
      return new AddedChildren(handlers, children, vdoms);
    } else {
      let $ = nodes.head;
      if ($ instanceof Fragment) {
        let rest = nodes.tail;
        let key = $.key;
        let nodes$1 = $.children;
        let path = add2(parent, child_index, key);
        let $1 = do_add_children(handlers, children, vdoms, path, 0, nodes$1);
        let handlers$1 = $1.handlers;
        let children$1 = $1.children;
        let vdoms$1 = $1.vdoms;
        loop$handlers = handlers$1;
        loop$children = children$1;
        loop$vdoms = vdoms$1;
        loop$parent = parent;
        loop$child_index = next;
        loop$nodes = rest;
      } else if ($ instanceof Element) {
        let rest = nodes.tail;
        let key = $.key;
        let attributes = $.attributes;
        let nodes$1 = $.children;
        let path = add2(parent, child_index, key);
        let handlers$1 = add_attributes(handlers, path, attributes);
        let $1 = do_add_children(handlers$1, children, vdoms, path, 0, nodes$1);
        let handlers$2 = $1.handlers;
        let children$1 = $1.children;
        let vdoms$1 = $1.vdoms;
        loop$handlers = handlers$2;
        loop$children = children$1;
        loop$vdoms = vdoms$1;
        loop$parent = parent;
        loop$child_index = next;
        loop$nodes = rest;
      } else if ($ instanceof Text) {
        let rest = nodes.tail;
        loop$handlers = handlers;
        loop$children = children;
        loop$vdoms = vdoms;
        loop$parent = parent;
        loop$child_index = next;
        loop$nodes = rest;
      } else if ($ instanceof UnsafeInnerHtml) {
        let rest = nodes.tail;
        let key = $.key;
        let attributes = $.attributes;
        let path = add2(parent, child_index, key);
        let handlers$1 = add_attributes(handlers, path, attributes);
        loop$handlers = handlers$1;
        loop$children = children;
        loop$vdoms = vdoms;
        loop$parent = parent;
        loop$child_index = next;
        loop$nodes = rest;
      } else if ($ instanceof Map2) {
        let rest = nodes.tail;
        let key = $.key;
        let mapper = $.mapper;
        let child2 = $.child;
        let path = add2(parent, child_index, key);
        let added = do_add_children(
          empty2(),
          empty2(),
          vdoms,
          subtree(path),
          0,
          singleton_list(child2)
        );
        let vdoms$1 = added.vdoms;
        let child_events = new Events(added.handlers, added.children);
        let child$1 = new Child(mapper, child_events);
        let children$1 = insert2(
          children,
          child(path),
          child$1
        );
        loop$handlers = handlers;
        loop$children = children$1;
        loop$vdoms = vdoms$1;
        loop$parent = parent;
        loop$child_index = next;
        loop$nodes = rest;
      } else {
        let rest = nodes.tail;
        let view3 = $.view;
        let child_node = view3();
        let vdoms$1 = insert2(vdoms, view3, child_node);
        let next$1 = child_index;
        let rest$1 = prepend(child_node, rest);
        loop$handlers = handlers;
        loop$children = children;
        loop$vdoms = vdoms$1;
        loop$parent = parent;
        loop$child_index = next$1;
        loop$nodes = rest$1;
      }
    }
  }
}
function add_children(cache, events2, path, child_index, nodes) {
  let vdoms = cache.vdoms;
  let handlers = events2.handlers;
  let children = events2.children;
  let $ = do_add_children(handlers, children, vdoms, path, child_index, nodes);
  let handlers$1 = $.handlers;
  let children$1 = $.children;
  let vdoms$1 = $.vdoms;
  return [
    new Cache(
      cache.events,
      vdoms$1,
      cache.old_vdoms,
      cache.dispatched_paths,
      cache.next_dispatched_paths
    ),
    new Events(handlers$1, children$1)
  ];
}
function add_child(cache, events2, parent, index4, child2) {
  let children = singleton_list(child2);
  return add_children(cache, events2, parent, index4, children);
}
function tick(cache) {
  return new Cache(
    cache.events,
    empty2(),
    cache.vdoms,
    cache.next_dispatched_paths,
    empty_list
  );
}
function events(cache) {
  return cache.events;
}
function update_events(cache, events2) {
  return new Cache(
    events2,
    cache.vdoms,
    cache.old_vdoms,
    cache.dispatched_paths,
    cache.next_dispatched_paths
  );
}
function memos(cache) {
  return cache.vdoms;
}
function get_old_memo(cache, old, new$7) {
  return get_or_compute(cache.old_vdoms, old, new$7);
}
function keep_memo(cache, old, new$7) {
  let node = get_or_compute(cache.old_vdoms, old, new$7);
  let vdoms = insert2(cache.vdoms, new$7, node);
  return new Cache(
    cache.events,
    vdoms,
    cache.old_vdoms,
    cache.dispatched_paths,
    cache.next_dispatched_paths
  );
}
function add_memo(cache, new$7, node) {
  let vdoms = insert2(cache.vdoms, new$7, node);
  return new Cache(
    cache.events,
    vdoms,
    cache.old_vdoms,
    cache.dispatched_paths,
    cache.next_dispatched_paths
  );
}
function get_subtree(events2, path, old_mapper) {
  let child2 = get_or_compute(
    events2.children,
    path,
    () => {
      return new Child(old_mapper, new_events());
    }
  );
  return child2.events;
}
function update_subtree(parent, path, mapper, events2) {
  let new_child = new Child(mapper, events2);
  let children = insert2(parent.children, path, new_child);
  return new Events(parent.handlers, children);
}
function add_event(events2, path, name, handler) {
  let handlers = do_add_event(events2.handlers, path, name, handler);
  return new Events(handlers, events2.children);
}
function do_remove_event(handlers, path, name) {
  return remove(handlers, event3(path, name));
}
function remove_event(events2, path, name) {
  let handlers = do_remove_event(events2.handlers, path, name);
  return new Events(handlers, events2.children);
}
function remove_attributes(handlers, path, attributes) {
  return fold2(
    attributes,
    handlers,
    (events2, attribute3) => {
      if (attribute3 instanceof Event2) {
        let name = attribute3.name;
        return do_remove_event(events2, path, name);
      } else {
        return events2;
      }
    }
  );
}
function do_remove_children(loop$handlers, loop$children, loop$vdoms, loop$parent, loop$index, loop$nodes) {
  while (true) {
    let handlers = loop$handlers;
    let children = loop$children;
    let vdoms = loop$vdoms;
    let parent = loop$parent;
    let index4 = loop$index;
    let nodes = loop$nodes;
    let next = index4 + 1;
    if (nodes instanceof Empty) {
      return new Events(handlers, children);
    } else {
      let $ = nodes.head;
      if ($ instanceof Fragment) {
        let rest = nodes.tail;
        let key = $.key;
        let nodes$1 = $.children;
        let path = add2(parent, index4, key);
        let $1 = do_remove_children(handlers, children, vdoms, path, 0, nodes$1);
        let handlers$1 = $1.handlers;
        let children$1 = $1.children;
        loop$handlers = handlers$1;
        loop$children = children$1;
        loop$vdoms = vdoms;
        loop$parent = parent;
        loop$index = next;
        loop$nodes = rest;
      } else if ($ instanceof Element) {
        let rest = nodes.tail;
        let key = $.key;
        let attributes = $.attributes;
        let nodes$1 = $.children;
        let path = add2(parent, index4, key);
        let handlers$1 = remove_attributes(handlers, path, attributes);
        let $1 = do_remove_children(
          handlers$1,
          children,
          vdoms,
          path,
          0,
          nodes$1
        );
        let handlers$2 = $1.handlers;
        let children$1 = $1.children;
        loop$handlers = handlers$2;
        loop$children = children$1;
        loop$vdoms = vdoms;
        loop$parent = parent;
        loop$index = next;
        loop$nodes = rest;
      } else if ($ instanceof Text) {
        let rest = nodes.tail;
        loop$handlers = handlers;
        loop$children = children;
        loop$vdoms = vdoms;
        loop$parent = parent;
        loop$index = next;
        loop$nodes = rest;
      } else if ($ instanceof UnsafeInnerHtml) {
        let rest = nodes.tail;
        let key = $.key;
        let attributes = $.attributes;
        let path = add2(parent, index4, key);
        let handlers$1 = remove_attributes(handlers, path, attributes);
        loop$handlers = handlers$1;
        loop$children = children;
        loop$vdoms = vdoms;
        loop$parent = parent;
        loop$index = next;
        loop$nodes = rest;
      } else if ($ instanceof Map2) {
        let rest = nodes.tail;
        let key = $.key;
        let path = add2(parent, index4, key);
        let children$1 = remove(children, child(path));
        loop$handlers = handlers;
        loop$children = children$1;
        loop$vdoms = vdoms;
        loop$parent = parent;
        loop$index = next;
        loop$nodes = rest;
      } else {
        let rest = nodes.tail;
        let view3 = $.view;
        let $1 = has_key(vdoms, view3);
        if ($1) {
          let child2 = get2(vdoms, view3);
          let nodes$1 = prepend(child2, rest);
          loop$handlers = handlers;
          loop$children = children;
          loop$vdoms = vdoms;
          loop$parent = parent;
          loop$index = index4;
          loop$nodes = nodes$1;
        } else {
          loop$handlers = handlers;
          loop$children = children;
          loop$vdoms = vdoms;
          loop$parent = parent;
          loop$index = next;
          loop$nodes = rest;
        }
      }
    }
  }
}
function remove_child(cache, events2, parent, child_index, child2) {
  return do_remove_children(
    events2.handlers,
    events2.children,
    cache.old_vdoms,
    parent,
    child_index,
    singleton_list(child2)
  );
}
function replace_child(cache, events2, parent, child_index, prev, next) {
  let events$1 = remove_child(cache, events2, parent, child_index, prev);
  return add_child(cache, events$1, parent, child_index, next);
}
function get_handler(loop$events, loop$path, loop$mapper) {
  while (true) {
    let events2 = loop$events;
    let path = loop$path;
    let mapper = loop$mapper;
    if (path instanceof Empty) {
      return error_nil;
    } else {
      let $ = path.tail;
      if ($ instanceof Empty) {
        let key = path.head;
        let $1 = has_key(events2.handlers, key);
        if ($1) {
          let handler = get2(events2.handlers, key);
          return new Ok(
            map3(
              handler,
              (handler2) => {
                return new Handler(
                  handler2.prevent_default,
                  handler2.stop_propagation,
                  identity2(mapper)(handler2.message)
                );
              }
            )
          );
        } else {
          return error_nil;
        }
      } else {
        let key = path.head;
        let path$1 = $;
        let $1 = has_key(events2.children, key);
        if ($1) {
          let child2 = get2(events2.children, key);
          let mapper$1 = compose_mapper(mapper, child2.mapper);
          loop$events = child2.events;
          loop$path = path$1;
          loop$mapper = mapper$1;
        } else {
          return error_nil;
        }
      }
    }
  }
}
function decode2(cache, path, name, event4) {
  let parts = split_subtree_path(path + separator_event + name);
  let $ = get_handler(cache.events, parts, identity2);
  if ($ instanceof Ok) {
    let handler = $[0];
    let $1 = run(event4, handler);
    if ($1 instanceof Ok) {
      let handler$1 = $1[0];
      return new DecodedEvent(path, handler$1);
    } else {
      return new DispatchedEvent(path);
    }
  } else {
    return new DispatchedEvent(path);
  }
}
function dispatch(cache, event4) {
  let next_dispatched_paths = prepend(
    event4.path,
    cache.next_dispatched_paths
  );
  let cache$1 = new Cache(
    cache.events,
    cache.vdoms,
    cache.old_vdoms,
    cache.dispatched_paths,
    next_dispatched_paths
  );
  if (event4 instanceof DecodedEvent) {
    let handler = event4.handler;
    return [cache$1, new Ok(handler)];
  } else {
    return [cache$1, error_nil];
  }
}
function has_dispatched_events(cache, path) {
  return matches(path, cache.dispatched_paths);
}

// public/build/dev/javascript/lustre/lustre/runtime/server/runtime.mjs
var EffectDispatchedMessage = class extends CustomType {
  constructor(message) {
    super();
    this.message = message;
  }
};
var Message$isEffectDispatchedMessage = (value2) => value2 instanceof EffectDispatchedMessage;
var EffectEmitEvent = class extends CustomType {
  constructor(name, data) {
    super();
    this.name = name;
    this.data = data;
  }
};
var Message$isEffectEmitEvent = (value2) => value2 instanceof EffectEmitEvent;
var SystemRequestedShutdown = class extends CustomType {
};
var Message$SystemRequestedShutdown$const = new SystemRequestedShutdown();
var Message$isSystemRequestedShutdown = (value2) => value2 instanceof SystemRequestedShutdown;

// public/build/dev/javascript/lustre/lustre/runtime/app.mjs
var App = class extends CustomType {
  constructor(name, init3, update4, view3, config) {
    super();
    this.name = name;
    this.init = init3;
    this.update = update4;
    this.view = view3;
    this.config = config;
  }
};
var Config2 = class extends CustomType {
  constructor(open_shadow_root, adopt_styles, delegates_focus, attributes, properties, contexts, is_form_associated, on_form_autofill, on_form_reset, on_form_restore, on_form_disabled, on_connect, on_adopt, on_disconnect) {
    super();
    this.open_shadow_root = open_shadow_root;
    this.adopt_styles = adopt_styles;
    this.delegates_focus = delegates_focus;
    this.attributes = attributes;
    this.properties = properties;
    this.contexts = contexts;
    this.is_form_associated = is_form_associated;
    this.on_form_autofill = on_form_autofill;
    this.on_form_reset = on_form_reset;
    this.on_form_restore = on_form_restore;
    this.on_form_disabled = on_form_disabled;
    this.on_connect = on_connect;
    this.on_adopt = on_adopt;
    this.on_disconnect = on_disconnect;
  }
};
var Option = class extends CustomType {
  constructor(apply) {
    super();
    this.apply = apply;
  }
};
var default_config = /* @__PURE__ */ new Config2(
  true,
  true,
  false,
  empty_list,
  empty_list,
  empty_list,
  false,
  Option$None$const,
  Option$None$const,
  Option$None$const,
  Option$None$const,
  Option$None$const,
  Option$None$const,
  Option$None$const
);
function configure(options) {
  return fold2(
    options,
    default_config,
    (config, option) => {
      return option.apply(config);
    }
  );
}

// public/build/dev/javascript/lustre/lustre/internals/equals.ffi.mjs
var isEqual2 = (a, b) => {
  if (a === b) {
    return true;
  }
  if (a == null || b == null) {
    return false;
  }
  const type = typeof a;
  if (type !== typeof b) {
    return false;
  }
  if (type !== "object") {
    return false;
  }
  const ctor = a.constructor;
  if (ctor !== b.constructor) {
    return false;
  }
  if (Array.isArray(a)) {
    return areArraysEqual(a, b);
  }
  return areObjectsEqual(a, b);
};
var areArraysEqual = (a, b) => {
  let index4 = a.length;
  if (index4 !== b.length) {
    return false;
  }
  while (index4--) {
    if (!isEqual2(a[index4], b[index4])) {
      return false;
    }
  }
  return true;
};
var areObjectsEqual = (a, b) => {
  const properties = Object.keys(a);
  let index4 = properties.length;
  if (Object.keys(b).length !== index4) {
    return false;
  }
  while (index4--) {
    const property3 = properties[index4];
    if (!Object.hasOwn(b, property3)) {
      return false;
    }
    if (!isEqual2(a[property3], b[property3])) {
      return false;
    }
  }
  return true;
};

// public/build/dev/javascript/lustre/lustre/vdom/diff.mjs
var Diff = class extends CustomType {
  constructor(patch, cache) {
    super();
    this.patch = patch;
    this.cache = cache;
  }
};
var PartialDiff = class extends CustomType {
  constructor(patch, cache, events2) {
    super();
    this.patch = patch;
    this.cache = cache;
    this.events = events2;
  }
};
var AttributeChange = class extends CustomType {
  constructor(added, removed, events2) {
    super();
    this.added = added;
    this.removed = removed;
    this.events = events2;
  }
};
function diff_attributes(loop$controlled, loop$path, loop$events, loop$old, loop$new, loop$added, loop$removed) {
  while (true) {
    let controlled = loop$controlled;
    let path = loop$path;
    let events2 = loop$events;
    let old = loop$old;
    let new$7 = loop$new;
    let added = loop$added;
    let removed = loop$removed;
    if (old instanceof Empty) {
      if (new$7 instanceof Empty) {
        return new AttributeChange(added, removed, events2);
      } else {
        let $ = new$7.head;
        if ($ instanceof Event2) {
          let next = $;
          let new$1 = new$7.tail;
          let name = $.name;
          let handler = $.handler;
          let events$1 = add_event(events2, path, name, handler);
          let added$1 = prepend(next, added);
          loop$controlled = controlled;
          loop$path = path;
          loop$events = events$1;
          loop$old = old;
          loop$new = new$1;
          loop$added = added$1;
          loop$removed = removed;
        } else {
          let next = $;
          let new$1 = new$7.tail;
          let added$1 = prepend(next, added);
          loop$controlled = controlled;
          loop$path = path;
          loop$events = events2;
          loop$old = old;
          loop$new = new$1;
          loop$added = added$1;
          loop$removed = removed;
        }
      }
    } else if (new$7 instanceof Empty) {
      let $ = old.head;
      if ($ instanceof Event2) {
        let prev = $;
        let old$1 = old.tail;
        let name = $.name;
        let events$1 = remove_event(events2, path, name);
        let removed$1 = prepend(prev, removed);
        loop$controlled = controlled;
        loop$path = path;
        loop$events = events$1;
        loop$old = old$1;
        loop$new = new$7;
        loop$added = added;
        loop$removed = removed$1;
      } else {
        let prev = $;
        let old$1 = old.tail;
        let removed$1 = prepend(prev, removed);
        loop$controlled = controlled;
        loop$path = path;
        loop$events = events2;
        loop$old = old$1;
        loop$new = new$7;
        loop$added = added;
        loop$removed = removed$1;
      }
    } else {
      let prev = old.head;
      let remaining_old = old.tail;
      let next = new$7.head;
      let remaining_new = new$7.tail;
      let $ = compare2(prev, next);
      if ($ instanceof Lt) {
        if (prev instanceof Event2) {
          let name = prev.name;
          loop$controlled = controlled;
          loop$path = path;
          loop$events = remove_event(events2, path, name);
          loop$old = remaining_old;
          loop$new = new$7;
          loop$added = added;
          loop$removed = prepend(prev, removed);
        } else {
          loop$controlled = controlled;
          loop$path = path;
          loop$events = events2;
          loop$old = remaining_old;
          loop$new = new$7;
          loop$added = added;
          loop$removed = prepend(prev, removed);
        }
      } else if ($ instanceof Eq) {
        if (prev instanceof Attribute) {
          if (next instanceof Attribute) {
            let _block;
            let $1 = next.name;
            if ($1 === "value") {
              _block = controlled || prev.value !== next.value;
            } else if ($1 === "checked") {
              _block = controlled || prev.value !== next.value;
            } else if ($1 === "selected") {
              _block = controlled || prev.value !== next.value;
            } else {
              _block = prev.value !== next.value;
            }
            let has_changes = _block;
            let _block$1;
            if (has_changes) {
              _block$1 = prepend(next, added);
            } else {
              _block$1 = added;
            }
            let added$1 = _block$1;
            loop$controlled = controlled;
            loop$path = path;
            loop$events = events2;
            loop$old = remaining_old;
            loop$new = remaining_new;
            loop$added = added$1;
            loop$removed = removed;
          } else if (next instanceof Event2) {
            let name = next.name;
            let handler = next.handler;
            loop$controlled = controlled;
            loop$path = path;
            loop$events = add_event(events2, path, name, handler);
            loop$old = remaining_old;
            loop$new = remaining_new;
            loop$added = prepend(next, added);
            loop$removed = prepend(prev, removed);
          } else {
            loop$controlled = controlled;
            loop$path = path;
            loop$events = events2;
            loop$old = remaining_old;
            loop$new = remaining_new;
            loop$added = prepend(next, added);
            loop$removed = prepend(prev, removed);
          }
        } else if (prev instanceof Property) {
          if (next instanceof Property) {
            let _block;
            let $1 = next.name;
            if ($1 === "scrollLeft") {
              _block = true;
            } else if ($1 === "scrollRight") {
              _block = true;
            } else if ($1 === "value") {
              _block = controlled || !isEqual2(
                prev.value,
                next.value
              );
            } else if ($1 === "checked") {
              _block = controlled || !isEqual2(
                prev.value,
                next.value
              );
            } else if ($1 === "selected") {
              _block = controlled || !isEqual2(
                prev.value,
                next.value
              );
            } else {
              _block = !isEqual2(prev.value, next.value);
            }
            let has_changes = _block;
            let _block$1;
            if (has_changes) {
              _block$1 = prepend(next, added);
            } else {
              _block$1 = added;
            }
            let added$1 = _block$1;
            loop$controlled = controlled;
            loop$path = path;
            loop$events = events2;
            loop$old = remaining_old;
            loop$new = remaining_new;
            loop$added = added$1;
            loop$removed = removed;
          } else if (next instanceof Event2) {
            let name = next.name;
            let handler = next.handler;
            loop$controlled = controlled;
            loop$path = path;
            loop$events = add_event(events2, path, name, handler);
            loop$old = remaining_old;
            loop$new = remaining_new;
            loop$added = prepend(next, added);
            loop$removed = prepend(prev, removed);
          } else {
            loop$controlled = controlled;
            loop$path = path;
            loop$events = events2;
            loop$old = remaining_old;
            loop$new = remaining_new;
            loop$added = prepend(next, added);
            loop$removed = prepend(prev, removed);
          }
        } else if (next instanceof Event2) {
          let name = next.name;
          let handler = next.handler;
          let has_changes = prev.prevent_default.kind !== next.prevent_default.kind || prev.stop_propagation.kind !== next.stop_propagation.kind || prev.debounce !== next.debounce || prev.throttle !== next.throttle;
          let _block;
          if (has_changes) {
            _block = prepend(next, added);
          } else {
            _block = added;
          }
          let added$1 = _block;
          loop$controlled = controlled;
          loop$path = path;
          loop$events = add_event(events2, path, name, handler);
          loop$old = remaining_old;
          loop$new = remaining_new;
          loop$added = added$1;
          loop$removed = removed;
        } else {
          let name = prev.name;
          loop$controlled = controlled;
          loop$path = path;
          loop$events = remove_event(events2, path, name);
          loop$old = remaining_old;
          loop$new = remaining_new;
          loop$added = prepend(next, added);
          loop$removed = prepend(prev, removed);
        }
      } else if (next instanceof Event2) {
        let name = next.name;
        let handler = next.handler;
        loop$controlled = controlled;
        loop$path = path;
        loop$events = add_event(events2, path, name, handler);
        loop$old = old;
        loop$new = remaining_new;
        loop$added = prepend(next, added);
        loop$removed = removed;
      } else {
        loop$controlled = controlled;
        loop$path = path;
        loop$events = events2;
        loop$old = old;
        loop$new = remaining_new;
        loop$added = prepend(next, added);
        loop$removed = removed;
      }
    }
  }
}
function is_controlled(cache, namespace, tag, path) {
  if (tag === "input" && namespace === "") {
    return has_dispatched_events(cache, path);
  } else if (tag === "select" && namespace === "") {
    return has_dispatched_events(cache, path);
  } else if (tag === "textarea" && namespace === "") {
    return has_dispatched_events(cache, path);
  } else {
    return false;
  }
}
function do_diff(loop$old, loop$old_keyed, loop$new, loop$new_keyed, loop$moved, loop$moved_offset, loop$removed, loop$node_index, loop$patch_index, loop$changes, loop$children, loop$path, loop$cache, loop$events) {
  while (true) {
    let old = loop$old;
    let old_keyed = loop$old_keyed;
    let new$7 = loop$new;
    let new_keyed = loop$new_keyed;
    let moved = loop$moved;
    let moved_offset = loop$moved_offset;
    let removed = loop$removed;
    let node_index = loop$node_index;
    let patch_index = loop$patch_index;
    let changes = loop$changes;
    let children = loop$children;
    let path = loop$path;
    let cache = loop$cache;
    let events2 = loop$events;
    if (old instanceof Empty) {
      if (new$7 instanceof Empty) {
        let _block;
        let $ = is_browser();
        if (changes instanceof Empty) {
          if (children instanceof Empty) {
            _block = new$3(patch_index, removed, changes, children);
          } else if (!$) {
            let $1 = children.tail;
            if ($1 instanceof Empty && removed === 0) {
              let child2 = children.head;
              _block = add_parent(child2, patch_index);
            } else {
              _block = new$3(patch_index, removed, changes, children);
            }
          } else {
            _block = new$3(patch_index, removed, changes, children);
          }
        } else {
          _block = new$3(patch_index, removed, changes, children);
        }
        let patch = _block;
        return new PartialDiff(patch, cache, events2);
      } else {
        let $ = add_children(cache, events2, path, node_index, new$7);
        let cache$1 = $[0];
        let events$1 = $[1];
        let insert4 = insert3(new$7, node_index - moved_offset);
        let changes$1 = prepend(insert4, changes);
        let patch = new$3(patch_index, removed, changes$1, children);
        return new PartialDiff(patch, cache$1, events$1);
      }
    } else if (new$7 instanceof Empty) {
      let prev = old.head;
      let old$1 = old.tail;
      let $ = prev.key === "" || !has_key(moved, prev.key);
      if ($) {
        let events$1 = remove_child(
          cache,
          events2,
          path,
          node_index,
          prev
        );
        loop$old = old$1;
        loop$old_keyed = old_keyed;
        loop$new = new$7;
        loop$new_keyed = new_keyed;
        loop$moved = moved;
        loop$moved_offset = moved_offset;
        loop$removed = removed + 1;
        loop$node_index = node_index;
        loop$patch_index = patch_index;
        loop$changes = changes;
        loop$children = children;
        loop$path = path;
        loop$cache = cache;
        loop$events = events$1;
      } else {
        loop$old = old$1;
        loop$old_keyed = old_keyed;
        loop$new = new$7;
        loop$new_keyed = new_keyed;
        loop$moved = moved;
        loop$moved_offset = moved_offset;
        loop$removed = removed;
        loop$node_index = node_index;
        loop$patch_index = patch_index;
        loop$changes = changes;
        loop$children = children;
        loop$path = path;
        loop$cache = cache;
        loop$events = events2;
      }
    } else {
      let prev = old.head;
      let next = new$7.head;
      if (prev.key !== next.key) {
        let old_remaining = old.tail;
        let new_remaining = new$7.tail;
        let next_did_exist = has_key(old_keyed, next.key);
        let prev_does_exist = has_key(new_keyed, prev.key);
        if (prev_does_exist) {
          if (next_did_exist) {
            let $ = has_key(moved, prev.key);
            if ($) {
              loop$old = old_remaining;
              loop$old_keyed = old_keyed;
              loop$new = new$7;
              loop$new_keyed = new_keyed;
              loop$moved = moved;
              loop$moved_offset = moved_offset - 1;
              loop$removed = removed;
              loop$node_index = node_index;
              loop$patch_index = patch_index;
              loop$changes = changes;
              loop$children = children;
              loop$path = path;
              loop$cache = cache;
              loop$events = events2;
            } else {
              let match = get2(old_keyed, next.key);
              let before = node_index - moved_offset;
              let changes$1 = prepend(
                move(next.key, before),
                changes
              );
              let moved$1 = insert2(moved, next.key, void 0);
              loop$old = prepend(match, old);
              loop$old_keyed = old_keyed;
              loop$new = new$7;
              loop$new_keyed = new_keyed;
              loop$moved = moved$1;
              loop$moved_offset = moved_offset + 1;
              loop$removed = removed;
              loop$node_index = node_index;
              loop$patch_index = patch_index;
              loop$changes = changes$1;
              loop$children = children;
              loop$path = path;
              loop$cache = cache;
              loop$events = events2;
            }
          } else {
            let before = node_index - moved_offset;
            let $ = add_child(cache, events2, path, node_index, next);
            let cache$1 = $[0];
            let events$1 = $[1];
            let insert4 = insert3(singleton_list(next), before);
            let changes$1 = prepend(insert4, changes);
            loop$old = old;
            loop$old_keyed = old_keyed;
            loop$new = new_remaining;
            loop$new_keyed = new_keyed;
            loop$moved = moved;
            loop$moved_offset = moved_offset + 1;
            loop$removed = removed;
            loop$node_index = node_index + 1;
            loop$patch_index = patch_index;
            loop$changes = changes$1;
            loop$children = children;
            loop$path = path;
            loop$cache = cache$1;
            loop$events = events$1;
          }
        } else if (next_did_exist) {
          let index4 = node_index - moved_offset;
          let changes$1 = prepend(remove2(index4), changes);
          let events$1 = remove_child(
            cache,
            events2,
            path,
            node_index,
            prev
          );
          loop$old = old_remaining;
          loop$old_keyed = old_keyed;
          loop$new = new$7;
          loop$new_keyed = new_keyed;
          loop$moved = moved;
          loop$moved_offset = moved_offset - 1;
          loop$removed = removed;
          loop$node_index = node_index;
          loop$patch_index = patch_index;
          loop$changes = changes$1;
          loop$children = children;
          loop$path = path;
          loop$cache = cache;
          loop$events = events$1;
        } else {
          let change = replace2(node_index - moved_offset, next);
          let $ = replace_child(
            cache,
            events2,
            path,
            node_index,
            prev,
            next
          );
          let cache$1 = $[0];
          let events$1 = $[1];
          loop$old = old_remaining;
          loop$old_keyed = old_keyed;
          loop$new = new_remaining;
          loop$new_keyed = new_keyed;
          loop$moved = moved;
          loop$moved_offset = moved_offset;
          loop$removed = removed;
          loop$node_index = node_index + 1;
          loop$patch_index = patch_index;
          loop$changes = prepend(change, changes);
          loop$children = children;
          loop$path = path;
          loop$cache = cache$1;
          loop$events = events$1;
        }
      } else {
        let $ = old.head;
        if ($ instanceof Fragment) {
          let $1 = new$7.head;
          if ($1 instanceof Fragment) {
            let prev2 = $;
            let old$1 = old.tail;
            let next2 = $1;
            let new$1 = new$7.tail;
            let $2 = do_diff(
              prev2.children,
              prev2.keyed_children,
              next2.children,
              next2.keyed_children,
              empty2(),
              0,
              0,
              0,
              node_index,
              empty_list,
              empty_list,
              add2(path, node_index, next2.key),
              cache,
              events2
            );
            let patch = $2.patch;
            let cache$1 = $2.cache;
            let events$1 = $2.events;
            let _block;
            let $3 = patch.changes;
            if ($3 instanceof Empty) {
              let $4 = patch.children;
              if ($4 instanceof Empty) {
                let $5 = patch.removed;
                if ($5 === 0) {
                  _block = children;
                } else {
                  _block = prepend(patch, children);
                }
              } else {
                _block = prepend(patch, children);
              }
            } else {
              _block = prepend(patch, children);
            }
            let children$1 = _block;
            loop$old = old$1;
            loop$old_keyed = old_keyed;
            loop$new = new$1;
            loop$new_keyed = new_keyed;
            loop$moved = moved;
            loop$moved_offset = moved_offset;
            loop$removed = removed;
            loop$node_index = node_index + 1;
            loop$patch_index = patch_index;
            loop$changes = changes;
            loop$children = children$1;
            loop$path = path;
            loop$cache = cache$1;
            loop$events = events$1;
          } else {
            let prev2 = $;
            let old_remaining = old.tail;
            let next2 = $1;
            let new_remaining = new$7.tail;
            let change = replace2(node_index - moved_offset, next2);
            let $2 = replace_child(
              cache,
              events2,
              path,
              node_index,
              prev2,
              next2
            );
            let cache$1 = $2[0];
            let events$1 = $2[1];
            loop$old = old_remaining;
            loop$old_keyed = old_keyed;
            loop$new = new_remaining;
            loop$new_keyed = new_keyed;
            loop$moved = moved;
            loop$moved_offset = moved_offset;
            loop$removed = removed;
            loop$node_index = node_index + 1;
            loop$patch_index = patch_index;
            loop$changes = prepend(change, changes);
            loop$children = children;
            loop$path = path;
            loop$cache = cache$1;
            loop$events = events$1;
          }
        } else if ($ instanceof Element) {
          let $1 = new$7.head;
          if ($1 instanceof Element) {
            let prev2 = $;
            let next2 = $1;
            if (prev2.namespace === next2.namespace && prev2.tag === next2.tag) {
              let old$1 = old.tail;
              let new$1 = new$7.tail;
              let child_path = add2(path, node_index, next2.key);
              let controlled = is_controlled(
                cache,
                next2.namespace,
                next2.tag,
                child_path
              );
              let $2 = diff_attributes(
                controlled,
                child_path,
                events2,
                prev2.attributes,
                next2.attributes,
                empty_list,
                empty_list
              );
              let added_attrs = $2.added;
              let removed_attrs = $2.removed;
              let events$1 = $2.events;
              let _block;
              if (added_attrs instanceof Empty && removed_attrs instanceof Empty) {
                _block = empty_list;
              } else {
                _block = singleton_list(
                  update(added_attrs, removed_attrs)
                );
              }
              let initial_child_changes = _block;
              let $3 = do_diff(
                prev2.children,
                prev2.keyed_children,
                next2.children,
                next2.keyed_children,
                empty2(),
                0,
                0,
                0,
                node_index,
                initial_child_changes,
                empty_list,
                child_path,
                cache,
                events$1
              );
              let patch = $3.patch;
              let cache$1 = $3.cache;
              let events$2 = $3.events;
              let _block$1;
              let $4 = patch.changes;
              if ($4 instanceof Empty) {
                let $5 = patch.children;
                if ($5 instanceof Empty) {
                  let $6 = patch.removed;
                  if ($6 === 0) {
                    _block$1 = children;
                  } else {
                    _block$1 = prepend(patch, children);
                  }
                } else {
                  _block$1 = prepend(patch, children);
                }
              } else {
                _block$1 = prepend(patch, children);
              }
              let children$1 = _block$1;
              loop$old = old$1;
              loop$old_keyed = old_keyed;
              loop$new = new$1;
              loop$new_keyed = new_keyed;
              loop$moved = moved;
              loop$moved_offset = moved_offset;
              loop$removed = removed;
              loop$node_index = node_index + 1;
              loop$patch_index = patch_index;
              loop$changes = changes;
              loop$children = children$1;
              loop$path = path;
              loop$cache = cache$1;
              loop$events = events$2;
            } else {
              let prev3 = $;
              let old_remaining = old.tail;
              let next3 = $1;
              let new_remaining = new$7.tail;
              let change = replace2(node_index - moved_offset, next3);
              let $2 = replace_child(
                cache,
                events2,
                path,
                node_index,
                prev3,
                next3
              );
              let cache$1 = $2[0];
              let events$1 = $2[1];
              loop$old = old_remaining;
              loop$old_keyed = old_keyed;
              loop$new = new_remaining;
              loop$new_keyed = new_keyed;
              loop$moved = moved;
              loop$moved_offset = moved_offset;
              loop$removed = removed;
              loop$node_index = node_index + 1;
              loop$patch_index = patch_index;
              loop$changes = prepend(change, changes);
              loop$children = children;
              loop$path = path;
              loop$cache = cache$1;
              loop$events = events$1;
            }
          } else {
            let prev2 = $;
            let old_remaining = old.tail;
            let next2 = $1;
            let new_remaining = new$7.tail;
            let change = replace2(node_index - moved_offset, next2);
            let $2 = replace_child(
              cache,
              events2,
              path,
              node_index,
              prev2,
              next2
            );
            let cache$1 = $2[0];
            let events$1 = $2[1];
            loop$old = old_remaining;
            loop$old_keyed = old_keyed;
            loop$new = new_remaining;
            loop$new_keyed = new_keyed;
            loop$moved = moved;
            loop$moved_offset = moved_offset;
            loop$removed = removed;
            loop$node_index = node_index + 1;
            loop$patch_index = patch_index;
            loop$changes = prepend(change, changes);
            loop$children = children;
            loop$path = path;
            loop$cache = cache$1;
            loop$events = events$1;
          }
        } else if ($ instanceof Text) {
          let $1 = new$7.head;
          if ($1 instanceof Text) {
            let prev2 = $;
            let next2 = $1;
            if (prev2.content === next2.content) {
              let old$1 = old.tail;
              let new$1 = new$7.tail;
              loop$old = old$1;
              loop$old_keyed = old_keyed;
              loop$new = new$1;
              loop$new_keyed = new_keyed;
              loop$moved = moved;
              loop$moved_offset = moved_offset;
              loop$removed = removed;
              loop$node_index = node_index + 1;
              loop$patch_index = patch_index;
              loop$changes = changes;
              loop$children = children;
              loop$path = path;
              loop$cache = cache;
              loop$events = events2;
            } else {
              let old$1 = old.tail;
              let next3 = $1;
              let new$1 = new$7.tail;
              let child2 = new$3(
                node_index,
                0,
                singleton_list(replace_text(next3.content)),
                empty_list
              );
              loop$old = old$1;
              loop$old_keyed = old_keyed;
              loop$new = new$1;
              loop$new_keyed = new_keyed;
              loop$moved = moved;
              loop$moved_offset = moved_offset;
              loop$removed = removed;
              loop$node_index = node_index + 1;
              loop$patch_index = patch_index;
              loop$changes = changes;
              loop$children = prepend(child2, children);
              loop$path = path;
              loop$cache = cache;
              loop$events = events2;
            }
          } else {
            let prev2 = $;
            let old_remaining = old.tail;
            let next2 = $1;
            let new_remaining = new$7.tail;
            let change = replace2(node_index - moved_offset, next2);
            let $2 = replace_child(
              cache,
              events2,
              path,
              node_index,
              prev2,
              next2
            );
            let cache$1 = $2[0];
            let events$1 = $2[1];
            loop$old = old_remaining;
            loop$old_keyed = old_keyed;
            loop$new = new_remaining;
            loop$new_keyed = new_keyed;
            loop$moved = moved;
            loop$moved_offset = moved_offset;
            loop$removed = removed;
            loop$node_index = node_index + 1;
            loop$patch_index = patch_index;
            loop$changes = prepend(change, changes);
            loop$children = children;
            loop$path = path;
            loop$cache = cache$1;
            loop$events = events$1;
          }
        } else if ($ instanceof UnsafeInnerHtml) {
          let $1 = new$7.head;
          if ($1 instanceof UnsafeInnerHtml) {
            let prev2 = $;
            let old$1 = old.tail;
            let next2 = $1;
            let new$1 = new$7.tail;
            let child_path = add2(path, node_index, next2.key);
            let $2 = diff_attributes(
              false,
              child_path,
              events2,
              prev2.attributes,
              next2.attributes,
              empty_list,
              empty_list
            );
            let added_attrs = $2.added;
            let removed_attrs = $2.removed;
            let events$1 = $2.events;
            let _block;
            if (added_attrs instanceof Empty && removed_attrs instanceof Empty) {
              _block = empty_list;
            } else {
              _block = singleton_list(
                update(added_attrs, removed_attrs)
              );
            }
            let child_changes = _block;
            let _block$1;
            let $3 = prev2.inner_html === next2.inner_html;
            if ($3) {
              _block$1 = child_changes;
            } else {
              _block$1 = prepend(
                replace_inner_html(next2.inner_html),
                child_changes
              );
            }
            let child_changes$1 = _block$1;
            let _block$2;
            if (child_changes$1 instanceof Empty) {
              _block$2 = children;
            } else {
              _block$2 = prepend(
                new$3(
                  node_index,
                  0,
                  child_changes$1,
                  empty_list
                ),
                children
              );
            }
            let children$1 = _block$2;
            loop$old = old$1;
            loop$old_keyed = old_keyed;
            loop$new = new$1;
            loop$new_keyed = new_keyed;
            loop$moved = moved;
            loop$moved_offset = moved_offset;
            loop$removed = removed;
            loop$node_index = node_index + 1;
            loop$patch_index = patch_index;
            loop$changes = changes;
            loop$children = children$1;
            loop$path = path;
            loop$cache = cache;
            loop$events = events$1;
          } else {
            let prev2 = $;
            let old_remaining = old.tail;
            let next2 = $1;
            let new_remaining = new$7.tail;
            let change = replace2(node_index - moved_offset, next2);
            let $2 = replace_child(
              cache,
              events2,
              path,
              node_index,
              prev2,
              next2
            );
            let cache$1 = $2[0];
            let events$1 = $2[1];
            loop$old = old_remaining;
            loop$old_keyed = old_keyed;
            loop$new = new_remaining;
            loop$new_keyed = new_keyed;
            loop$moved = moved;
            loop$moved_offset = moved_offset;
            loop$removed = removed;
            loop$node_index = node_index + 1;
            loop$patch_index = patch_index;
            loop$changes = prepend(change, changes);
            loop$children = children;
            loop$path = path;
            loop$cache = cache$1;
            loop$events = events$1;
          }
        } else if ($ instanceof Map2) {
          let $1 = new$7.head;
          if ($1 instanceof Map2) {
            let prev2 = $;
            let old$1 = old.tail;
            let next2 = $1;
            let new$1 = new$7.tail;
            let child_path = add2(path, node_index, next2.key);
            let child_key = child(child_path);
            let $2 = do_diff(
              singleton_list(prev2.child),
              empty2(),
              singleton_list(next2.child),
              empty2(),
              empty2(),
              0,
              0,
              0,
              node_index,
              empty_list,
              empty_list,
              subtree(child_path),
              cache,
              get_subtree(events2, child_key, prev2.mapper)
            );
            let patch = $2.patch;
            let cache$1 = $2.cache;
            let child_events = $2.events;
            let events$1 = update_subtree(
              events2,
              child_key,
              next2.mapper,
              child_events
            );
            let _block;
            let $3 = patch.changes;
            if ($3 instanceof Empty) {
              let $4 = patch.children;
              if ($4 instanceof Empty) {
                let $5 = patch.removed;
                if ($5 === 0) {
                  _block = children;
                } else {
                  _block = prepend(patch, children);
                }
              } else {
                _block = prepend(patch, children);
              }
            } else {
              _block = prepend(patch, children);
            }
            let children$1 = _block;
            loop$old = old$1;
            loop$old_keyed = old_keyed;
            loop$new = new$1;
            loop$new_keyed = new_keyed;
            loop$moved = moved;
            loop$moved_offset = moved_offset;
            loop$removed = removed;
            loop$node_index = node_index + 1;
            loop$patch_index = patch_index;
            loop$changes = changes;
            loop$children = children$1;
            loop$path = path;
            loop$cache = cache$1;
            loop$events = events$1;
          } else {
            let prev2 = $;
            let old_remaining = old.tail;
            let next2 = $1;
            let new_remaining = new$7.tail;
            let change = replace2(node_index - moved_offset, next2);
            let $2 = replace_child(
              cache,
              events2,
              path,
              node_index,
              prev2,
              next2
            );
            let cache$1 = $2[0];
            let events$1 = $2[1];
            loop$old = old_remaining;
            loop$old_keyed = old_keyed;
            loop$new = new_remaining;
            loop$new_keyed = new_keyed;
            loop$moved = moved;
            loop$moved_offset = moved_offset;
            loop$removed = removed;
            loop$node_index = node_index + 1;
            loop$patch_index = patch_index;
            loop$changes = prepend(change, changes);
            loop$children = children;
            loop$path = path;
            loop$cache = cache$1;
            loop$events = events$1;
          }
        } else {
          let $1 = new$7.head;
          if ($1 instanceof Memo) {
            let prev2 = $;
            let old$1 = old.tail;
            let next2 = $1;
            let new$1 = new$7.tail;
            let $2 = equal_lists(prev2.dependencies, next2.dependencies);
            if ($2) {
              let cache$1 = keep_memo(cache, prev2.view, next2.view);
              loop$old = old$1;
              loop$old_keyed = old_keyed;
              loop$new = new$1;
              loop$new_keyed = new_keyed;
              loop$moved = moved;
              loop$moved_offset = moved_offset;
              loop$removed = removed;
              loop$node_index = node_index + 1;
              loop$patch_index = patch_index;
              loop$changes = changes;
              loop$children = children;
              loop$path = path;
              loop$cache = cache$1;
              loop$events = events2;
            } else {
              let prev_node = get_old_memo(cache, prev2.view, prev2.view);
              let next_node = next2.view();
              let cache$1 = add_memo(cache, next2.view, next_node);
              loop$old = prepend(prev_node, old$1);
              loop$old_keyed = old_keyed;
              loop$new = prepend(next_node, new$1);
              loop$new_keyed = new_keyed;
              loop$moved = moved;
              loop$moved_offset = moved_offset;
              loop$removed = removed;
              loop$node_index = node_index;
              loop$patch_index = patch_index;
              loop$changes = changes;
              loop$children = children;
              loop$path = path;
              loop$cache = cache$1;
              loop$events = events2;
            }
          } else {
            let prev2 = $;
            let old_remaining = old.tail;
            let next2 = $1;
            let new_remaining = new$7.tail;
            let change = replace2(node_index - moved_offset, next2);
            let $2 = replace_child(
              cache,
              events2,
              path,
              node_index,
              prev2,
              next2
            );
            let cache$1 = $2[0];
            let events$1 = $2[1];
            loop$old = old_remaining;
            loop$old_keyed = old_keyed;
            loop$new = new_remaining;
            loop$new_keyed = new_keyed;
            loop$moved = moved;
            loop$moved_offset = moved_offset;
            loop$removed = removed;
            loop$node_index = node_index + 1;
            loop$patch_index = patch_index;
            loop$changes = prepend(change, changes);
            loop$children = children;
            loop$path = path;
            loop$cache = cache$1;
            loop$events = events$1;
          }
        }
      }
    }
  }
}
function diff(cache, old, new$7) {
  let cache$1 = tick(cache);
  let $ = do_diff(
    singleton_list(old),
    empty2(),
    singleton_list(new$7),
    empty2(),
    empty2(),
    0,
    0,
    0,
    0,
    empty_list,
    empty_list,
    root,
    cache$1,
    events(cache$1)
  );
  let patch = $.patch;
  let cache$2 = $.cache;
  let events2 = $.events;
  return new Diff(patch, update_events(cache$2, events2));
}

// public/build/dev/javascript/lustre/lustre/internals/list.ffi.mjs
var iterate = (list4, callback) => {
  if (Array.isArray(list4)) {
    for (let i = 0; i < list4.length; i++) {
      callback(list4[i]);
    }
  } else if (list4) {
    for (list4; List$NonEmpty$rest(list4); list4 = List$NonEmpty$rest(list4)) {
      callback(List$NonEmpty$first(list4));
    }
  }
};
var append4 = (a, b) => {
  if (!List$NonEmpty$rest(a)) {
    return b;
  } else if (!List$NonEmpty$rest(b)) {
    return a;
  } else {
    return append(a, b);
  }
};

// public/build/dev/javascript/lustre/lustre/internals/constants.ffi.mjs
var NAMESPACE_HTML = "http://www.w3.org/1999/xhtml";
var ELEMENT_NODE = 1;
var TEXT_NODE = 3;
var COMMENT_NODE = 8;
var SUPPORTS_MOVE_BEFORE = !!globalThis.HTMLElement?.prototype?.moveBefore;

// public/build/dev/javascript/lustre/lustre/vdom/reconciler.ffi.mjs
var setTimeout = globalThis.setTimeout;
var clearTimeout = globalThis.clearTimeout;
var createElementNS = (ns, name) => globalThis.document.createElementNS(ns, name);
var createTextNode = (data) => globalThis.document.createTextNode(data);
var createComment = (data) => globalThis.document.createComment(data);
var createDocumentFragment = () => globalThis.document.createDocumentFragment();
var insertBefore = (parent, node, reference) => parent.insertBefore(node, reference);
var moveBefore = SUPPORTS_MOVE_BEFORE ? (parent, node, reference) => parent.moveBefore(node, reference) : insertBefore;
var removeChild = (parent, child2) => parent.removeChild(child2);
var getAttribute = (node, name) => node.getAttribute(name);
var setAttribute = (node, name, value2) => node.setAttribute(name, value2);
var removeAttribute = (node, name) => node.removeAttribute(name);
var addEventListener = (node, name, handler, options) => node.addEventListener(name, handler, options);
var removeEventListener = (node, name, handler) => node.removeEventListener(name, handler);
var setInnerHtml = (node, innerHtml) => node.innerHTML = innerHtml;
var setData = (node, data) => node.data = data;
var meta = /* @__PURE__ */ Symbol("lustre");
var MetadataNode = class {
  constructor(kind, parent, node, key) {
    this.kind = kind;
    this.key = key;
    this.parent = parent;
    this.children = [];
    this.node = node;
    this.endNode = null;
    this.handlers = /* @__PURE__ */ new Map();
    this.throttles = /* @__PURE__ */ new Map();
    this.debouncers = /* @__PURE__ */ new Map();
  }
  get isVirtual() {
    return this.kind === fragment_kind || this.kind === map_kind;
  }
  get parentNode() {
    return this.isVirtual ? this.node.parentNode : this.node;
  }
};
var insertMetadataChild = (kind, parent, node, index4, key) => {
  const child2 = new MetadataNode(kind, parent, node, key);
  node[meta] = child2;
  parent?.children.splice(index4, 0, child2);
  return child2;
};
var getPath = (node) => {
  let path = "";
  for (let current = node[meta]; current.parent; current = current.parent) {
    const separator = current.parent && current.parent.kind === map_kind ? separator_subtree : separator_element;
    if (current.key) {
      path = `${separator}${current.key}${path}`;
    } else {
      const index4 = current.parent.children.indexOf(current);
      path = `${separator}${index4}${path}`;
    }
  }
  return path.slice(1);
};
var Reconciler = class {
  #root = null;
  #decodeEvent;
  #dispatch;
  #debug = false;
  constructor(root2, decodeEvent, dispatch2, { debug = false } = {}) {
    this.#root = root2;
    this.#decodeEvent = decodeEvent;
    this.#dispatch = dispatch2;
    this.#debug = debug;
  }
  mount(vdom) {
    insertMetadataChild(element_kind, null, this.#root, 0, null);
    this.#insertChild(this.#root, null, this.#root[meta], 0, vdom);
  }
  push(patch, memos2 = null) {
    this.#memos = memos2;
    this.#stack.push({ node: this.#root[meta], patch });
    this.#reconcile();
  }
  // PATCHING ------------------------------------------------------------------
  #memos;
  #stack = [];
  #reconcile() {
    const stack = this.#stack;
    while (stack.length) {
      let { node, patch } = stack.pop();
      const { path, changes, removed, children: childPatches } = patch;
      iterate(path, (index4) => {
        node = node.children[index4];
      });
      const { children: childNodes } = node;
      iterate(changes, (change) => this.#patch(node, change));
      if (removed) {
        this.#removeChildren(node, childNodes.length - removed, removed);
      }
      iterate(childPatches, (childPatch) => {
        const child2 = childNodes[childPatch.index | 0];
        this.#stack.push({ node: child2, patch: childPatch });
      });
    }
  }
  #patch(node, change) {
    switch (change.kind) {
      case replace_text_kind:
        this.#replaceText(node, change);
        break;
      case replace_inner_html_kind:
        this.#replaceInnerHtml(node, change);
        break;
      case update_kind:
        this.#update(node, change);
        break;
      case move_kind:
        this.#move(node, change);
        break;
      case remove_kind:
        this.#remove(node, change);
        break;
      case replace_kind:
        this.#replace(node, change);
        break;
      case insert_kind:
        this.#insert(node, change);
        break;
    }
  }
  // CHANGES -------------------------------------------------------------------
  #insert(parent, { children, before }) {
    const fragment5 = createDocumentFragment();
    const beforeEl = this.#getReference(parent, before);
    this.#insertChildren(fragment5, null, parent, before | 0, children);
    insertBefore(parent.parentNode, fragment5, beforeEl);
  }
  #replace(parent, { index: index4, with: child2 }) {
    this.#removeChildren(parent, index4 | 0, 1);
    const beforeEl = this.#getReference(parent, index4);
    this.#insertChild(parent.parentNode, beforeEl, parent, index4 | 0, child2);
  }
  #getReference(node, index4) {
    index4 = index4 | 0;
    const { children } = node;
    const childCount = children.length;
    if (index4 < childCount) return children[index4].node;
    if (node.endNode) return node.endNode;
    if (!node.isVirtual) return null;
    while (node.isVirtual && node.children.length) {
      if (node.endNode) return node.endNode.nextSibling;
      node = node.children[node.children.length - 1];
    }
    return node.node.nextSibling;
  }
  #move(parent, { key, before }) {
    before = before | 0;
    const { children, parentNode } = parent;
    const beforeEl = children[before].node;
    let prev = children[before];
    for (let i = before + 1; i < children.length; ++i) {
      const next = children[i];
      children[i] = prev;
      prev = next;
      if (next.key === key) {
        children[before] = next;
        break;
      }
    }
    this.#moveChild(parentNode, prev, beforeEl);
  }
  #moveChildren(domParent, children, beforeEl) {
    for (let i = 0; i < children.length; ++i) {
      this.#moveChild(domParent, children[i], beforeEl);
    }
  }
  #moveChild(domParent, child2, beforeEl) {
    moveBefore(domParent, child2.node, beforeEl);
    if (child2.isVirtual) {
      this.#moveChildren(domParent, child2.children, beforeEl);
    }
    if (child2.endNode) {
      moveBefore(domParent, child2.endNode, beforeEl);
    }
  }
  #remove(parent, { index: index4 }) {
    this.#removeChildren(parent, index4, 1);
  }
  #removeChildren(parent, index4, count) {
    const { children, parentNode } = parent;
    const deleted = children.splice(index4, count);
    for (let i = 0; i < deleted.length; ++i) {
      const child2 = deleted[i];
      const { node, endNode, isVirtual, children: nestedChildren } = child2;
      removeChild(parentNode, node);
      if (endNode) {
        removeChild(parentNode, endNode);
      }
      this.#removeDebouncers(child2);
      if (isVirtual) {
        deleted.push(...nestedChildren);
      }
    }
  }
  #removeDebouncers(node) {
    const { debouncers, children } = node;
    for (const { timeout } of debouncers.values()) {
      if (timeout) {
        clearTimeout(timeout);
      }
    }
    debouncers.clear();
    iterate(children, (child2) => this.#removeDebouncers(child2));
  }
  #update({ node, handlers, throttles, debouncers }, { added, removed }) {
    iterate(removed, ({ name }) => {
      if (handlers.delete(name)) {
        removeEventListener(node, name, handleEvent);
        this.#updateDebounceThrottle(throttles, name, 0);
        this.#updateDebounceThrottle(debouncers, name, 0);
      } else {
        removeAttribute(node, name);
        SYNCED_ATTRIBUTES[name]?.removed?.(node, name);
      }
    });
    iterate(added, (attribute3) => this.#createAttribute(node, attribute3));
  }
  #replaceText({ node }, { content }) {
    setData(node, content ?? "");
  }
  #replaceInnerHtml({ node }, { inner_html }) {
    setInnerHtml(node, inner_html ?? "");
  }
  // INSERT --------------------------------------------------------------------
  #insertChildren(domParent, beforeEl, metaParent, index4, children) {
    iterate(
      children,
      (child2) => this.#insertChild(domParent, beforeEl, metaParent, index4++, child2)
    );
  }
  #insertChild(domParent, beforeEl, metaParent, index4, vnode) {
    switch (vnode.kind) {
      case element_kind: {
        const node = this.#createElement(metaParent, index4, vnode);
        this.#insertChildren(node, null, node[meta], 0, vnode.children);
        insertBefore(domParent, node, beforeEl);
        break;
      }
      case text_kind: {
        const node = this.#createTextNode(metaParent, index4, vnode);
        insertBefore(domParent, node, beforeEl);
        break;
      }
      case fragment_kind: {
        const marker = "lustre:fragment";
        const head = this.#createHead(marker, metaParent, index4, vnode);
        insertBefore(domParent, head, beforeEl);
        this.#insertChildren(
          domParent,
          beforeEl,
          head[meta],
          0,
          vnode.children
        );
        if (this.#debug) {
          head[meta].endNode = createComment(` /${marker} `);
          insertBefore(domParent, head[meta].endNode, beforeEl);
        }
        break;
      }
      case unsafe_inner_html_kind: {
        const node = this.#createElement(metaParent, index4, vnode);
        this.#replaceInnerHtml({ node }, vnode);
        insertBefore(domParent, node, beforeEl);
        break;
      }
      case map_kind: {
        const head = this.#createHead("lustre:map", metaParent, index4, vnode);
        insertBefore(domParent, head, beforeEl);
        this.#insertChild(domParent, beforeEl, head[meta], 0, vnode.child);
        break;
      }
      case memo_kind: {
        const child2 = this.#memos?.get(vnode.view) ?? vnode.view();
        this.#insertChild(domParent, beforeEl, metaParent, index4, child2);
        break;
      }
    }
  }
  #createElement(parent, index4, { kind, key, tag, namespace, attributes }) {
    const node = createElementNS(namespace || NAMESPACE_HTML, tag);
    insertMetadataChild(kind, parent, node, index4, key);
    if (this.#debug && key) {
      setAttribute(node, "data-lustre-key", key);
    }
    iterate(attributes, (attribute3) => this.#createAttribute(node, attribute3));
    return node;
  }
  #createTextNode(parent, index4, { kind, key, content }) {
    const node = createTextNode(content ?? "");
    insertMetadataChild(kind, parent, node, index4, key);
    return node;
  }
  #createHead(marker, parent, index4, { kind, key }) {
    const node = this.#debug ? createComment(markerComment(marker, key)) : createTextNode("");
    insertMetadataChild(kind, parent, node, index4, key);
    return node;
  }
  #createAttribute(node, attribute3) {
    const { debouncers, handlers, throttles } = node[meta];
    const {
      kind,
      name,
      value: value2,
      prevent_default: prevent,
      debounce: debounceDelay,
      throttle: throttleDelay
    } = attribute3;
    switch (kind) {
      case attribute_kind: {
        const valueOrDefault = value2 ?? "";
        if (name === "virtual:defaultValue") {
          node.defaultValue = valueOrDefault;
          return;
        } else if (name === "virtual:defaultChecked") {
          node.defaultChecked = true;
          return;
        } else if (name === "virtual:defaultSelected") {
          node.defaultSelected = true;
          return;
        }
        if (valueOrDefault !== getAttribute(node, name)) {
          setAttribute(node, name, valueOrDefault);
        }
        SYNCED_ATTRIBUTES[name]?.added?.(node, valueOrDefault);
        break;
      }
      case property_kind:
        node[name] = value2;
        break;
      case event_kind: {
        if (handlers.has(name)) {
          removeEventListener(node, name, handleEvent);
        }
        const passive = prevent.kind === never_kind;
        addEventListener(node, name, handleEvent, { passive });
        this.#updateDebounceThrottle(throttles, name, throttleDelay);
        this.#updateDebounceThrottle(debouncers, name, debounceDelay);
        handlers.set(name, (event4) => this.#handleEvent(attribute3, event4));
        break;
      }
    }
  }
  #updateDebounceThrottle(map7, name, delay) {
    const debounceOrThrottle = map7.get(name);
    if (delay > 0) {
      if (debounceOrThrottle) {
        debounceOrThrottle.delay = delay;
      } else {
        map7.set(name, { delay });
      }
    } else if (debounceOrThrottle) {
      const { timeout } = debounceOrThrottle;
      if (timeout) {
        clearTimeout(timeout);
      }
      map7.delete(name);
    }
  }
  #handleEvent(attribute3, event4) {
    const { currentTarget, type } = event4;
    const { debouncers, throttles } = currentTarget[meta];
    const path = getPath(currentTarget);
    const {
      prevent_default: prevent,
      stop_propagation: stop,
      include
    } = attribute3;
    if (prevent.kind === always_kind) event4.preventDefault();
    if (stop.kind === always_kind) event4.stopPropagation();
    if (type === "submit") {
      event4.detail ??= {};
      event4.detail.formData = [
        ...new FormData(event4.target, event4.submitter).entries()
      ];
    }
    const data = this.#decodeEvent(event4, path, type, include);
    const throttle = throttles.get(type);
    if (throttle) {
      const now = Date.now();
      const last = throttle.last || 0;
      if (now > last + throttle.delay) {
        throttle.last = now;
        throttle.lastEvent = event4;
        this.#dispatch(event4, data);
      }
    }
    const debounce = debouncers.get(type);
    if (debounce) {
      clearTimeout(debounce.timeout);
      debounce.timeout = setTimeout(() => {
        if (event4 === throttles.get(type)?.lastEvent) return;
        this.#dispatch(event4, data);
      }, debounce.delay);
    }
    if (!throttle && !debounce) {
      this.#dispatch(event4, data);
    }
  }
};
var markerComment = (marker, key) => {
  if (key) {
    return ` ${marker} key="${escape(key)}" `;
  } else {
    return ` ${marker} `;
  }
};
var handleEvent = (event4) => {
  const { currentTarget, type } = event4;
  const handler = currentTarget[meta].handlers.get(type);
  handler(event4);
};
var syncedBooleanAttribute = /* @__NO_SIDE_EFFECTS__ */ (name) => {
  return {
    added(node) {
      node[name] = true;
    },
    removed(node) {
      node[name] = false;
    }
  };
};
var syncedAttribute = /* @__NO_SIDE_EFFECTS__ */ (name) => {
  return {
    added(node, value2) {
      node[name] = value2;
    }
  };
};
var SYNCED_ATTRIBUTES = {
  checked: /* @__PURE__ */ syncedBooleanAttribute("checked"),
  selected: /* @__PURE__ */ syncedBooleanAttribute("selected"),
  value: /* @__PURE__ */ syncedAttribute("value"),
  autofocus: {
    added(node) {
      queueMicrotask(() => {
        node.focus?.();
      });
    }
  },
  autoplay: {
    added(node) {
      try {
        node.play?.();
      } catch (e) {
        console.error(e);
      }
    }
  }
};

// public/build/dev/javascript/lustre/lustre/element/keyed.mjs
function do_extract_keyed_children(loop$key_children_pairs, loop$keyed_children, loop$children) {
  while (true) {
    let key_children_pairs = loop$key_children_pairs;
    let keyed_children = loop$keyed_children;
    let children = loop$children;
    if (key_children_pairs instanceof Empty) {
      return [keyed_children, reverse(children)];
    } else {
      let rest = key_children_pairs.tail;
      let key = key_children_pairs.head[0];
      let element$1 = key_children_pairs.head[1];
      let keyed_element = to_keyed(key, element$1);
      let _block;
      if (key === "") {
        _block = keyed_children;
      } else {
        _block = insert2(keyed_children, key, keyed_element);
      }
      let keyed_children$1 = _block;
      let children$1 = prepend(keyed_element, children);
      loop$key_children_pairs = rest;
      loop$keyed_children = keyed_children$1;
      loop$children = children$1;
    }
  }
}
function extract_keyed_children(children) {
  return do_extract_keyed_children(
    children,
    empty2(),
    empty_list
  );
}
function element3(tag, attributes, children) {
  let $ = extract_keyed_children(children);
  let keyed_children = $[0];
  let children$1 = $[1];
  return element(
    "",
    "",
    tag,
    attributes,
    children$1,
    keyed_children,
    false,
    is_void_html_element(tag, "")
  );
}
function namespaced2(namespace, tag, attributes, children) {
  let $ = extract_keyed_children(children);
  let keyed_children = $[0];
  let children$1 = $[1];
  return element(
    "",
    namespace,
    tag,
    attributes,
    children$1,
    keyed_children,
    false,
    is_void_html_element(tag, namespace)
  );
}
function fragment2(children) {
  let $ = extract_keyed_children(children);
  let keyed_children = $[0];
  let children$1 = $[1];
  return fragment("", children$1, keyed_children);
}

// public/build/dev/javascript/lustre/lustre/vdom/virtualise.ffi.mjs
var virtualise = (root2) => {
  const rootMeta = insertMetadataChild(element_kind, null, root2, 0, null);
  const { children } = virtualiseChildren(rootMeta, root2, root2.firstChild);
  if (children.length > 1) {
    const rootNodeMeta = insertMetadataChild(element_kind, null, root2, 0, null);
    rootMeta.kind = fragment_kind;
    rootMeta.node = globalThis.document.createTextNode("");
    rootMeta.parent = rootNodeMeta;
    rootNodeMeta.children.push(rootMeta);
    root2.insertBefore(rootMeta.node, root2.firstChild);
    return fragment2(toList2(children));
  }
  if (children.length === 1) {
    return children[0][1];
  }
  const placeholder = globalThis.document.createTextNode("");
  insertMetadataChild(text_kind, rootMeta, placeholder, 0, null);
  root2.insertBefore(placeholder, root2.firstChild);
  return none2();
};
var virtualiseChild = (meta2, domParent, child2, index4) => {
  if (child2.nodeType === COMMENT_NODE) {
    const data = child2.data.trim();
    if (data.startsWith("lustre:fragment")) {
      return virtualiseFragment(meta2, domParent, child2, index4);
    }
    if (data.startsWith("lustre:map")) {
      return virtualiseMap(meta2, domParent, child2, index4);
    }
    if (data.startsWith("lustre:memo")) {
      return virtualiseMemo(meta2, domParent, child2, index4);
    }
    return null;
  }
  if (child2.nodeType === ELEMENT_NODE) {
    return virtualiseElement(meta2, child2, index4);
  }
  if (child2.nodeType === TEXT_NODE) {
    return virtualiseText(meta2, child2, index4);
  }
  return null;
};
var virtualiseElement = (metaParent, node, index4) => {
  const key = node.getAttribute("data-lustre-key") ?? "";
  if (key) {
    node.removeAttribute("data-lustre-key");
  }
  const meta2 = insertMetadataChild(element_kind, metaParent, node, index4, key);
  const tag = node.localName;
  const namespace = node.namespaceURI;
  const isHtmlElement = !namespace || namespace === NAMESPACE_HTML;
  if (isHtmlElement && INPUT_ELEMENTS.includes(tag)) {
    virtualiseInputEvents(tag, node);
  }
  const attributes = virtualiseAttributes(node);
  const { children } = virtualiseChildren(meta2, node, node.firstChild);
  const vnode = isHtmlElement ? element3(tag, attributes, toList2(children)) : namespaced2(namespace, tag, attributes, toList2(children));
  return childResult(key, vnode, node.nextSibling);
};
var virtualiseChildren = (meta2, domParent, childNode) => {
  const children = [];
  while (childNode && (childNode.nodeType !== COMMENT_NODE || childNode.data.trim() !== "/lustre:fragment")) {
    const child2 = virtualiseChild(meta2, domParent, childNode, children.length);
    if (child2) {
      children.push([child2.key, child2.vnode]);
      childNode = child2.next;
    } else {
      childNode = childNode.nextSibling;
    }
  }
  return { children, end: childNode };
};
var virtualiseText = (meta2, node, index4) => {
  insertMetadataChild(text_kind, meta2, node, index4, null);
  return childResult("", text2(node.data), node.nextSibling);
};
var virtualiseFragment = (metaParent, domParent, node, index4) => {
  const key = parseKey(node.data);
  const meta2 = insertMetadataChild(fragment_kind, metaParent, node, index4, key);
  const { children, end } = virtualiseChildren(meta2, domParent, node.nextSibling);
  meta2.endNode = end;
  const vnode = fragment2(toList2(children));
  return childResult(key, vnode, end?.nextSibling);
};
var virtualiseMap = (metaParent, domParent, node, index4) => {
  const key = parseKey(node.data);
  const meta2 = insertMetadataChild(map_kind, metaParent, node, index4, key);
  const child2 = virtualiseNextChild(meta2, domParent, node, 0);
  if (!child2) return null;
  const vnode = map5(child2.vnode, (x) => x);
  return childResult(key, vnode, child2.next);
};
var virtualiseMemo = (meta2, domParent, node, index4) => {
  const key = parseKey(node.data);
  const child2 = virtualiseNextChild(meta2, domParent, node, index4);
  if (!child2) return null;
  domParent.removeChild(node);
  const vnode = memo2(toList2([ref({})]), () => child2.vnode);
  return childResult(key, vnode, child2.next);
};
var virtualiseNextChild = (meta2, domParent, node, index4) => {
  while (true) {
    node = node.nextSibling;
    if (!node) return null;
    const child2 = virtualiseChild(meta2, domParent, node, index4);
    if (child2) return child2;
  }
};
var childResult = (key, vnode, next) => {
  return { key, vnode, next };
};
var virtualiseAttributes = (node) => {
  const attributes = [];
  for (let i = 0; i < node.attributes.length; i++) {
    const attr = node.attributes[i];
    if (attr.name !== "xmlns") {
      attributes.push(attribute2(attr.localName, attr.value));
    }
  }
  return toList2(attributes);
};
var INPUT_ELEMENTS = ["input", "select", "textarea"];
var virtualiseInputEvents = (tag, node) => {
  const value2 = node.value;
  const checked = node.checked;
  if (tag === "input" && node.type === "checkbox" && !checked) return;
  if (tag === "input" && node.type === "radio" && !checked) return;
  if (node.type !== "checkbox" && node.type !== "radio" && !value2) return;
  queueMicrotask(() => {
    node.value = value2;
    node.checked = checked;
    node.dispatchEvent(new Event("input", { bubbles: true }));
    node.dispatchEvent(new Event("change", { bubbles: true }));
    if (globalThis.document.activeElement !== node) {
      node.dispatchEvent(new Event("blur", { bubbles: true }));
    }
  });
};
var parseKey = (data) => {
  const keyMatch = data.match(/key="([^"]*)"/);
  if (!keyMatch) return "";
  return unescapeKey(keyMatch[1]);
};
var unescapeKey = (key) => {
  return key.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&amp;/g, "&").replace(/&#39;/g, "'");
};
var toList2 = (arr) => arr.reduceRight((xs, x) => List$NonEmpty(x, xs), empty_list);

// public/build/dev/javascript/lustre/lustre/runtime/client/runtime.ffi.mjs
var is_browser = () => !!globalThis.document;
var Runtime = class {
  constructor(root2, [model, effects], view3, update4, options) {
    this.root = root2;
    this.#model = model;
    this.#view = view3;
    this.#update = update4;
    this.root.addEventListener("context-request", (event4) => {
      if (!(event4.context && event4.callback)) return;
      if (!this.#contexts.has(event4.context)) return;
      event4.stopImmediatePropagation();
      const context = this.#contexts.get(event4.context);
      if (event4.subscribe) {
        const unsubscribe2 = () => {
          context.subscribers = context.subscribers.filter(
            (subscriber) => subscriber !== event4.callback
          );
        };
        context.subscribers.push([event4.callback, unsubscribe2]);
        event4.callback(context.value, unsubscribe2);
      } else {
        event4.callback(context.value);
      }
    });
    const decodeEvent = (event4, path, name) => decode2(this.#cache, path, name, event4);
    const dispatch2 = (event4, data) => {
      const [cache, result] = dispatch(this.#cache, data);
      this.#cache = cache;
      if (Result$isOk(result)) {
        const handler = Result$Ok$0(result);
        if (handler.stop_propagation) event4.stopPropagation();
        if (handler.prevent_default) event4.preventDefault();
        this.dispatch(handler.message, false);
      }
    };
    this.#reconciler = new Reconciler(
      this.root,
      decodeEvent,
      dispatch2,
      options
    );
    this.#vdom = virtualise(this.root);
    this.#cache = new$4();
    this.#handleEffects(effects);
    this.#render();
  }
  // PUBLIC API ----------------------------------------------------------------
  root = null;
  dispatch(message, shouldFlush = false) {
    if (this.#shouldQueue) {
      this.#queue.push(message);
    } else {
      const [model, effects] = this.#update(this.#model, message);
      this.#model = model;
      this.#scheduleRender(shouldFlush);
      this.#handleEffects(effects);
    }
  }
  emit(event4, data) {
    const target = this.root.host ?? this.root;
    target.dispatchEvent(new LustreEvent(event4, data));
  }
  // Provide a context value for any child nodes that request it using the given
  // key. If the key already exists, any existing subscribers will be notified
  // of the change. Otherwise, we store the value and wait for any `context-request`
  // events to come in.
  provide(key, value2) {
    if (!this.#contexts.has(key)) {
      this.#contexts.set(key, { value: value2, subscribers: [] });
    } else {
      const context = this.#contexts.get(key);
      if (isEqual2(context.value, value2)) {
        return;
      }
      context.value = value2;
      for (let i = context.subscribers.length - 1; i >= 0; i--) {
        const [subscriber, unsubscribe2] = context.subscribers[i];
        if (!subscriber) {
          context.subscribers.splice(i, 1);
          continue;
        }
        subscriber(value2, unsubscribe2);
      }
    }
  }
  subscribe(key, decoder4) {
    if (!key) return;
    this.#contextSubscriptions.get(key)?.();
    const target = this.root.host ?? this.root;
    target.dispatchEvent(
      new ContextRequestEvent(
        key,
        (value2, unsubscribe2) => {
          const previousUnsubscribe = this.#contextSubscriptions.get(key);
          if (previousUnsubscribe !== unsubscribe2) {
            previousUnsubscribe?.();
          }
          const decoded = run(value2, decoder4);
          this.#contextSubscriptions.set(key, unsubscribe2);
          if (Result$isOk(decoded)) {
            this.dispatch(Result$Ok$0(decoded), true);
          }
        },
        true
      )
    );
  }
  unsubscribe(key) {
    const unsubscribe2 = this.#contextSubscriptions.get(key);
    if (unsubscribe2) {
      unsubscribe2();
      this.#contextSubscriptions.delete(key);
    }
  }
  unsubscribeAll() {
    for (const [_, unsubscribe2] of this.#contextSubscriptions) {
      unsubscribe2?.();
    }
    this.#contextSubscriptions.clear();
  }
  // PRIVATE API ---------------------------------------------------------------
  #model;
  #view;
  #update;
  #vdom;
  #cache;
  #reconciler;
  #contexts = /* @__PURE__ */ new Map();
  #contextSubscriptions = /* @__PURE__ */ new Map();
  #shouldQueue = false;
  #queue = [];
  #beforePaint = empty_list;
  #afterPaint = empty_list;
  #renderTimer = null;
  #actions = {
    dispatch: (message) => this.dispatch(message),
    emit: (event4, data) => this.emit(event4, data),
    select: () => {
    },
    root: () => this.root,
    provide: (key, value2) => this.provide(key, value2),
    subscribe: (key, decoder4) => this.subscribe(key, decoder4),
    unsubscribe: (key) => this.unsubscribe(key)
  };
  #scheduleRender(shouldFlush = false) {
    if (this.#renderTimer) return;
    if (shouldFlush) {
      this.#renderTimer = "sync";
      queueMicrotask(() => this.#render());
    } else {
      this.#renderTimer = window.requestAnimationFrame(() => this.#render());
    }
  }
  // #handleEffects processes all effects, without scheduling a render.
  #handleEffects(effects) {
    this.#shouldQueue = true;
    let updateCalledDuringEffects = false;
    while (true) {
      iterate(effects.synchronous, (effect) => effect(this.#actions));
      this.#beforePaint = append4(this.#beforePaint, effects.before_paint);
      this.#afterPaint = append4(this.#afterPaint, effects.after_paint);
      if (!this.#queue.length) break;
      const message = this.#queue.shift();
      [this.#model, effects] = this.#update(this.#model, message);
      updateCalledDuringEffects = true;
    }
    this.#shouldQueue = false;
    return updateCalledDuringEffects;
  }
  // Async effects (before_paint and after_paint) can trigger without causing a
  // new model update. Here we process these effects and schedules the next
  // (synchronous) frame if required.
  #handleAsyncEffects(effects) {
    if (this.#handleEffects(effects)) {
      this.#scheduleRender(true);
    }
  }
  #render() {
    this.#renderTimer = null;
    const next = this.#view(this.#model);
    const { patch, cache } = diff(this.#cache, this.#vdom, next);
    this.#cache = cache;
    this.#vdom = next;
    this.#reconciler.push(patch, memos(cache));
    if (List$isNonEmpty(this.#beforePaint)) {
      const effects = makeEffect(this.#beforePaint);
      this.#beforePaint = empty_list;
      queueMicrotask(() => this.#handleAsyncEffects(effects));
    }
    if (List$isNonEmpty(this.#afterPaint)) {
      const effects = makeEffect(this.#afterPaint);
      this.#afterPaint = empty_list;
      window.requestAnimationFrame(() => this.#handleAsyncEffects(effects));
    }
  }
};
function makeEffect(synchronous) {
  return {
    synchronous,
    after_paint: empty_list,
    before_paint: empty_list
  };
}
var copiedStyleSheets = /* @__PURE__ */ new WeakMap();
async function adoptStylesheets(shadowRoot) {
  const pendingParentStylesheets = [];
  for (const node of globalThis.document.querySelectorAll(
    "link[rel=stylesheet], style"
  )) {
    if (node.sheet) continue;
    pendingParentStylesheets.push(
      new Promise((resolve, reject) => {
        node.addEventListener("load", resolve);
        node.addEventListener("error", reject);
      })
    );
  }
  await Promise.allSettled(pendingParentStylesheets);
  if (!shadowRoot.host.isConnected) {
    return [];
  }
  shadowRoot.adoptedStyleSheets = shadowRoot.host.getRootNode().adoptedStyleSheets;
  const pending = [];
  for (const sheet of globalThis.document.styleSheets) {
    try {
      shadowRoot.adoptedStyleSheets.push(sheet);
    } catch {
      try {
        let copiedSheet = copiedStyleSheets.get(sheet);
        if (!copiedSheet) {
          copiedSheet = new CSSStyleSheet();
          for (const rule of sheet.cssRules) {
            copiedSheet.insertRule(rule.cssText, copiedSheet.cssRules.length);
          }
          copiedStyleSheets.set(sheet, copiedSheet);
        }
        shadowRoot.adoptedStyleSheets.push(copiedSheet);
      } catch {
        const node = sheet.ownerNode.cloneNode();
        shadowRoot.prepend(node);
        pending.push(node);
      }
    }
  }
  return pending;
}
var ContextRequestEvent = class extends Event {
  constructor(context, callback, subscribe2) {
    super("context-request", { bubbles: true, composed: true });
    this.context = context;
    this.callback = callback;
    this.subscribe = subscribe2;
  }
};
var LustreEvent = class extends CustomEvent {
  // We can't rely on `instanceof` checks because the server component client
  // runtime is bundled on its own and thus will have its own copy of this class.
  isLustreEvent = true;
  constructor(name, detail) {
    super(name, { detail, bubbles: true, composed: true });
  }
};

// public/build/dev/javascript/lustre/lustre/runtime/client/component.ffi.mjs
var make_component = ({ init: init3, update: update4, view: view3, config }, name) => {
  if (!is_browser()) return Result$Error(Error$NotABrowser());
  if (!name.includes("-")) return Result$Error(Error$BadComponentName(name));
  if (globalThis.customElements.get(name)) {
    return Result$Error(Error$ComponentAlreadyRegistered(name));
  }
  const attributes = /* @__PURE__ */ new Map();
  const observedAttributes = [];
  iterate(config.attributes, ([name2, decoder4]) => {
    if (attributes.has(name2)) return;
    attributes.set(name2, decoder4);
    observedAttributes.push(name2);
  });
  const [model, effects] = init3(void 0);
  const component2 = class Component extends globalThis.HTMLElement {
    static get observedAttributes() {
      return observedAttributes;
    }
    static formAssociated = config.is_form_associated;
    #runtime;
    #adoptedStyleNodes = [];
    #initialContexts = config.contexts;
    constructor() {
      super();
      this.internals = this.attachInternals();
      if (!this.internals.shadowRoot) {
        this.attachShadow({
          mode: config.open_shadow_root ? "open" : "closed",
          delegatesFocus: config.delegates_focus
        });
      }
      if (config.adopt_styles) {
        this.#adoptStyleSheets();
      }
      this.#runtime = new Runtime(
        this.internals.shadowRoot,
        [model, effects],
        view3,
        update4
      );
    }
    // CUSTOM ELEMENT LIFECYCLE METHODS ----------------------------------------
    // When an element is constructed by `document.createElement` and then added
    // to the DOM, the lifecycle callbacks run in this order:
    //
    //   constructor -> attributeChangedCallback -> connectedCallback
    //
    // If the element is added to the document through `document.importNode` then
    // we get:
    //
    //   constructor -> connectedCallback
    //
    // The connectedCallback is also called when the element is moved to a new
    // position in the same document, so it's important we don't do any *one-time*
    // work here.
    //
    connectedCallback() {
      this.#requestContexts();
      if (Option$isSome(config.on_connect)) {
        this.dispatch(Option$Some$0(config.on_connect));
      }
    }
    // If the element is imported into the document through `document.adoptNode`
    // then the lifecycle callbacks are:
    //
    //   disconnectedCallback -> adoptedCallback -> connectedCallback
    //
    adoptedCallback() {
      if (config.adopt_styles) {
        this.#adoptStyleSheets();
      }
      this.#unsubscribeContexts();
      if (Option$isSome(config.on_adopt)) {
        this.dispatch(Option$Some$0(config.on_adopt));
      }
    }
    // The disconnected callback is also called when the element is disconnected
    // from the document even if it is reconnected somewhere else. It's important
    // we use this callback just for DOM-related cleanup.
    //
    disconnectedCallback() {
      this.#unsubscribeContexts();
      if (Option$isSome(config.on_disconnect)) {
        this.dispatch(Option$Some$0(config.on_disconnect));
      }
    }
    attributeChangedCallback(name2, _, value2) {
      const decoded = attributes.get(name2)(value2 ?? "");
      if (Result$isOk(decoded)) {
        this.dispatch(Result$Ok$0(decoded), true);
      }
    }
    formResetCallback() {
      if (Option$isSome(config.on_form_reset)) {
        this.dispatch(Option$Some$0(config.on_form_reset));
      }
    }
    formStateRestoreCallback(state, reason) {
      switch (reason) {
        case "restore":
          if (Option$isSome(config.on_form_restore)) {
            this.dispatch(Option$Some$0(config.on_form_restore)(state));
          }
          break;
        case "autocomplete":
          if (Option$isSome(config.on_form_autofill)) {
            this.dispatch(Option$Some$0(config.on_form_autofill)(state));
          }
          break;
      }
    }
    formDisabledCallback(disabled2) {
      if (Option$isSome(config.on_form_disabled)) {
        this.dispatch(Option$Some$0(config.on_form_disabled)(disabled2));
      }
    }
    // LUSTRE RUNTIME METHODS --------------------------------------------------
    send(message) {
      if (Message$isEffectDispatchedMessage(message)) {
        this.dispatch(message.message, false);
      } else if (Message$isEffectEmitEvent(message)) {
        this.emit(message.name, message.data);
      } else if (Message$isSystemRequestedShutdown(message)) {
      }
    }
    dispatch(message, shouldFlush = false) {
      this.#runtime.dispatch(message, shouldFlush);
    }
    emit(event4, data) {
      this.#runtime.emit(event4, data);
    }
    provide(key, value2) {
      this.#runtime.provide(key, value2);
    }
    subscribe(key, decoder4) {
      this.#runtime.subscribe(key, decoder4);
    }
    unsubscribe(key) {
      this.#runtime.unsubscribe(key);
      this.#initialContexts = filter(this.#initialContexts, (subscription) => {
        return subscription[0] !== key;
      });
    }
    // INTERNAL METHODS --------------------------------------------------------
    #requestContexts() {
      const requested = /* @__PURE__ */ new Set();
      iterate(this.#initialContexts, ([key, decoder4]) => {
        if (!key) return;
        if (requested.has(key)) return;
        this.#runtime.subscribe(key, decoder4);
        requested.add(key);
      });
    }
    #unsubscribeContexts() {
      this.#runtime.unsubscribeAll();
    }
    async #adoptStyleSheets() {
      while (this.#adoptedStyleNodes.length) {
        this.#adoptedStyleNodes.pop().remove();
        this.shadowRoot.firstChild.remove();
      }
      this.#adoptedStyleNodes = await adoptStylesheets(
        this.internals.shadowRoot
      );
    }
  };
  iterate(config.properties, ([name2, decoder4]) => {
    if (Object.hasOwn(component2.prototype, name2)) {
      return;
    }
    Object.defineProperty(component2.prototype, name2, {
      get() {
        return this[`_${name2}`];
      },
      set(value2) {
        this[`_${name2}`] = value2;
        const decoded = run(value2, decoder4);
        if (Result$isOk(decoded)) {
          this.dispatch(Result$Ok$0(decoded), true);
        }
      }
    });
  });
  globalThis.customElements.define(name, component2);
  return Result$Ok(void 0);
};

// public/build/dev/javascript/lustre/lustre/component.mjs
function on_attribute_change(name, decoder4) {
  return new Option(
    (config) => {
      let attributes = prepend([name, decoder4], config.attributes);
      return new Config2(
        config.open_shadow_root,
        config.adopt_styles,
        config.delegates_focus,
        attributes,
        config.properties,
        config.contexts,
        config.is_form_associated,
        config.on_form_autofill,
        config.on_form_reset,
        config.on_form_restore,
        config.on_form_disabled,
        config.on_connect,
        config.on_adopt,
        config.on_disconnect
      );
    }
  );
}

// public/build/dev/javascript/lustre/lustre.mjs
var BadComponentName = class extends CustomType {
  constructor(name) {
    super();
    this.name = name;
  }
};
var Error$BadComponentName = (name) => new BadComponentName(name);
var ComponentAlreadyRegistered = class extends CustomType {
  constructor(name) {
    super();
    this.name = name;
  }
};
var Error$ComponentAlreadyRegistered = (name) => new ComponentAlreadyRegistered(name);
var NotABrowser = class extends CustomType {
};
var Error$NotABrowser$const = new NotABrowser();
var Error$NotABrowser = () => Error$NotABrowser$const;
function component(init3, update4, view3, options) {
  return new App(
    Option$None$const,
    init3,
    update4,
    view3,
    configure(options)
  );
}

// public/build/dev/javascript/lustre/lustre/event.mjs
function emit2(event4, data) {
  return event2(event4, data);
}
function on(name, handler) {
  return event(
    name,
    map3(
      handler,
      (message) => {
        return new Handler(false, false, message);
      }
    ),
    empty_list,
    never,
    never,
    0,
    0
  );
}
function on_click(message) {
  return on("click", success(message));
}
function on_change(message) {
  return on(
    "change",
    subfield(
      toList(["target", "value"]),
      string2,
      (value2) => {
        return success(message(value2));
      }
    )
  );
}

// public/build/dev/javascript/sketch/sketch/internals/cache/cache.mjs
var NoStyle = class extends CustomType {
};
var Style$NoStyle$const = new NoStyle();

// public/build/dev/javascript/sketch/sketch/css/media.mjs
var Dark = class extends CustomType {
};
var ColorMode$Dark$const = new Dark();
var Light = class extends CustomType {
};
var ColorMode$Light$const = new Light();
var Screen = class extends CustomType {
};
var Query$Screen$const = new Screen();
var Print = class extends CustomType {
};
var Query$Print$const = new Print();
var All2 = class extends CustomType {
};
var Query$All$const = new All2();

// public/build/dev/javascript/sketch/sketch.mjs
var Ephemeral = class extends CustomType {
};
var Strategy$Ephemeral$const = new Ephemeral();
var Persistent = class extends CustomType {
};
var Strategy$Persistent$const = new Persistent();

// public/build/dev/javascript/sketch_lustre/sketch/lustre/element.mjs
var text3 = text2;
function element_(tag, attributes, children) {
  return element2(tag, attributes, children);
}

// public/build/dev/javascript/sketch_lustre/sketch/lustre/element/html.mjs
function button_(attributes, children) {
  return element_("button", attributes, children);
}
function div_(attributes, children) {
  return element_("div", attributes, children);
}
function option_(attributes, children) {
  return element_("option", attributes, children);
}
function select_(attributes, children) {
  return element_("select", attributes, children);
}

// public/build/dev/javascript/yumemi/framework/front/el.mjs
var text4 = text3;

// public/build/dev/javascript/yumemi/framework/front/live.mjs
var State = class extends CustomType {
  constructor(args, given, last, waiting) {
    super();
    this.args = args;
    this.given = given;
    this.last = last;
    this.waiting = waiting;
  }
};
var Set2 = class extends CustomType {
  constructor($0, $1) {
    super();
    this[0] = $0;
    this[1] = $1;
  }
};
var Send = class extends CustomType {
};
var Event$Send$const = new Send();
var Given = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var Done = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var Stay = class extends CustomType {
};
var After$Stay$const = new Stay();
var ReloadPage = class extends CustomType {
};
var After$ReloadPage$const = new ReloadPage();

// public/build/dev/javascript/yumemi/framework/spec_ffi.mjs
function matches2(raw, pattern) {
  return new RegExp(pattern, "u").test(raw);
}
var codepoints = (raw) => Array.from(raw).length;
function validInteger(raw, min2, max2) {
  if (!/^-?(?:0|[1-9][0-9]*)$/.test(raw)) return false;
  const n = Number(raw);
  return Number.isSafeInteger(n) && n >= min2 && n <= max2;
}
function validUrl(raw) {
  try {
    const u = new URL(raw);
    return ["http:", "https:"].includes(u.protocol) && !!u.hostname && !u.username && !u.password;
  } catch {
    return false;
  }
}

// public/build/dev/javascript/yumemi/framework/spec.mjs
var Uuid = class extends CustomType {
};
var Spec$Uuid$const = new Uuid();
var Pattern = class extends CustomType {
  constructor(min2, max2, regex) {
    super();
    this.min = min2;
    this.max = max2;
    this.regex = regex;
  }
};
var Text2 = class extends CustomType {
  constructor(min2, max2) {
    super();
    this.min = min2;
    this.max = max2;
  }
};
var Markdown = class extends CustomType {
};
var Spec$Markdown$const = new Markdown();
var MarkdownText = class extends CustomType {
  constructor(min2, max2) {
    super();
    this.min = min2;
    this.max = max2;
  }
};
var Range = class extends CustomType {
  constructor(min2, max2) {
    super();
    this.min = min2;
    this.max = max2;
  }
};
var Url = class extends CustomType {
};
var Spec$Url$const = new Url();
var Invalid = class extends CustomType {
};
var Error$Invalid$const = new Invalid();
function within(raw, min2, max2) {
  let length2 = codepoints(raw);
  return length2 >= min2 && length2 <= max2;
}
function validate(raw, spec) {
  let _block;
  if (spec instanceof Uuid) {
    _block = matches2(
      raw,
      "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
    );
  } else if (spec instanceof Pattern) {
    let min2 = spec.min;
    let max2 = spec.max;
    let regex = spec.regex;
    _block = within(raw, min2, max2) && matches2(raw, regex);
  } else if (spec instanceof Text2) {
    let min2 = spec.min;
    let max2 = spec.max;
    _block = within(raw, min2, max2);
  } else if (spec instanceof Markdown) {
    _block = true;
  } else if (spec instanceof MarkdownText) {
    let min2 = spec.min;
    let max2 = spec.max;
    _block = within(raw, min2, max2);
  } else if (spec instanceof Range) {
    let min2 = spec.min;
    let max2 = spec.max;
    _block = validInteger(raw, min2, max2);
  } else {
    _block = validUrl(raw);
  }
  let valid = _block;
  if (valid) {
    return new Ok(raw);
  } else {
    return new Error(Error$Invalid$const);
  }
}

// public/build/dev/javascript/public/gen/out/article_publish.mjs
var Has = class extends CustomType {
  constructor(value2) {
    super();
    this.value = value2;
  }
};
var Multi = class extends CustomType {
  constructor(values3) {
    super();
    this.values = values3;
  }
};
var Article = class extends CustomType {
  constructor(slug, title, body, version, order, category, tags) {
    super();
    this.slug = slug;
    this.title = title;
    this.body = body;
    this.version = version;
    this.order = order;
    this.category = category;
    this.tags = tags;
  }
};
function decoder() {
  return field(
    "slug",
    string2,
    (slug) => {
      return field(
        "title",
        string2,
        (title) => {
          return field(
            "body",
            string2,
            (body) => {
              return field(
                "version",
                int2,
                (version) => {
                  return field(
                    "order",
                    int2,
                    (order) => {
                      return field(
                        "category",
                        field(
                          "value",
                          string2,
                          (value2) => {
                            return success(new Has(value2));
                          }
                        ),
                        (category) => {
                          return field(
                            "tags",
                            field(
                              "values",
                              list2(string2),
                              (values3) => {
                                return success(new Multi(values3));
                              }
                            ),
                            (tags) => {
                              return success(
                                new Article(
                                  slug,
                                  title,
                                  body,
                                  version,
                                  order,
                                  category,
                                  tags
                                )
                              );
                            }
                          );
                        }
                      );
                    }
                  );
                }
              );
            }
          );
        }
      );
    }
  );
}

// public/build/dev/javascript/public/gen/live/transport_ffi.mjs
function send2(method, path, body, onOk, onError) {
  fetch(path, {
    method,
    headers: { "content-type": "application/json" },
    body: method === "GET" ? void 0 : JSON.stringify(body)
  }).then((response) => response.ok ? response.json().then(onOk) : onError(void 0)).catch(() => onError(void 0));
  return void 0;
}

// public/build/dev/javascript/public/gen/live/article_publish.mjs
var Args = class extends CustomType {
  constructor(slug) {
    super();
    this.slug = slug;
  }
};
var Slug = class extends CustomType {
};
var Field$Slug$const = new Slug();
var Invalid2 = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var Failed = class extends CustomType {
};
var Error$Failed$const = new Failed();
function init(given) {
  return [
    new State(new Args(""), given, Option$None$const, false),
    none()
  ];
}
function send3(args) {
  return from2(
    (dispatch2) => {
      return send2(
        "POST",
        "/api/articles/" + args.slug + "/publish",
        object2(toList([["slug", string3(args.slug)]])),
        (value2) => {
          let $ = run(value2, decoder());
          if ($ instanceof Ok) {
            let out = $[0];
            return dispatch2(new Done(new Ok(out)));
          } else {
            return dispatch2(new Done(new Error(Error$Failed$const)));
          }
        },
        (_) => {
          return dispatch2(new Done(new Error(Error$Failed$const)));
        }
      );
    }
  );
}
function validate_field(field2, raw, constraint) {
  let $ = validate(raw, constraint);
  if ($ instanceof Ok) {
    return List$Empty$const;
  } else {
    return toList([[field2, "invalid"]]);
  }
}
function validate2(model) {
  let errors = flatten(
    toList([
      validate_field(
        Field$Slug$const,
        model.args.slug,
        new Pattern(1, 64, "^[a-z0-9]+(-[a-z0-9]+)*$")
      )
    ])
  );
  if (errors instanceof Empty) {
    return new Ok(model.args);
  } else {
    return new Error(errors);
  }
}
function update2(model, msg) {
  if (msg instanceof Set2) {
    let value2 = msg[1];
    return [
      new State(new Args(value2), model.given, model.last, model.waiting),
      none()
    ];
  } else if (msg instanceof Send) {
    let $ = model.waiting;
    if ($) {
      return [model, none()];
    } else {
      let $1 = validate2(model);
      if ($1 instanceof Ok) {
        let args = $1[0];
        return [
          new State(model.args, model.given, model.last, true),
          send3(args)
        ];
      } else {
        let errors = $1[0];
        return [
          new State(
            model.args,
            model.given,
            new Some(new Error(new Invalid2(errors))),
            model.waiting
          ),
          none()
        ];
      }
    }
  } else if (msg instanceof Given) {
    let given = msg[0];
    return [
      new State(model.args, given, model.last, model.waiting),
      none()
    ];
  } else {
    let result = msg[0];
    let next = new State(model.args, model.given, new Some(result), false);
    if (result instanceof Ok) {
      return [next, none()];
    } else {
      return [next, none()];
    }
  }
}

// public/build/dev/javascript/public/gen/service.mjs
var ArticleCreate = class extends CustomType {
};
var Service$ArticleCreate$const = new ArticleCreate();
var ArticleList = class extends CustomType {
};
var Service$ArticleList$const = new ArticleList();
var ArticlePublish = class extends CustomType {
};
var Service$ArticlePublish$const = new ArticlePublish();
var ArticleRead = class extends CustomType {
};
var Service$ArticleRead$const = new ArticleRead();
var ArticleRetract = class extends CustomType {
};
var Service$ArticleRetract$const = new ArticleRetract();
var WidgetList = class extends CustomType {
};
var Service$WidgetList$const = new WidgetList();

// public/build/dev/javascript/public/components/like_button.mjs
function label(model) {
  let $ = model.last;
  if ($ instanceof Some) {
    let $1 = $[0];
    if ($1 instanceof Ok) {
      let article = $1[0];
      return "\u2764 " + to_string(article.version);
    } else {
      return "\u3044\u3044\u306D";
    }
  } else {
    return "\u3044\u3044\u306D";
  }
}
function view(it) {
  return button_(
    toList([
      on_click(Event$Send$const),
      disabled(it.waiting)
    ]),
    toList([text4(label(it))])
  );
}
function app() {
  return component(
    init,
    update2,
    view,
    toList([
      on_attribute_change(
        "slug",
        (value2) => {
          return new Ok(
            new Set2(Field$Slug$const, value2)
          );
        }
      )
    ])
  );
}

// public/build/dev/javascript/public/gen/out/article_create.mjs
function decoder2() {
  return string2;
}

// public/build/dev/javascript/yumemi/framework/page.mjs
var Cursor = class extends CustomType {
  constructor(value2) {
    super();
    this.value = value2;
  }
};
var Page = class extends CustomType {
  constructor(items, next) {
    super();
    this.items = items;
    this.next = next;
  }
};
function cursor(raw) {
  if (raw === "") {
    return new Error(void 0);
  } else {
    return new Ok(new Cursor(raw));
  }
}

// public/build/dev/javascript/public/gen/out/article_list.mjs
var FILEPATH = "src/gen/out/article_list.gleam";
var Has2 = class extends CustomType {
  constructor(value2) {
    super();
    this.value = value2;
  }
};
var Multi2 = class extends CustomType {
  constructor(values3) {
    super();
    this.values = values3;
  }
};
var Article2 = class extends CustomType {
  constructor(slug, title, body, version, order, category, tags) {
    super();
    this.slug = slug;
    this.title = title;
    this.body = body;
    this.version = version;
    this.order = order;
    this.category = category;
    this.tags = tags;
  }
};
var Category = class extends CustomType {
  constructor(name) {
    super();
    this.name = name;
  }
};
var Out = class extends CustomType {
  constructor(page, counts) {
    super();
    this.page = page;
    this.counts = counts;
  }
};
function decoder3() {
  return field(
    "page",
    field(
      "items",
      list2(
        field(
          "slug",
          string2,
          (slug) => {
            return field(
              "title",
              string2,
              (title) => {
                return field(
                  "body",
                  string2,
                  (body) => {
                    return field(
                      "version",
                      int2,
                      (version) => {
                        return field(
                          "order",
                          int2,
                          (order) => {
                            return field(
                              "category",
                              field(
                                "value",
                                string2,
                                (value2) => {
                                  return success(new Has2(value2));
                                }
                              ),
                              (category) => {
                                return field(
                                  "tags",
                                  field(
                                    "values",
                                    list2(string2),
                                    (values3) => {
                                      return success(new Multi2(values3));
                                    }
                                  ),
                                  (tags) => {
                                    return success(
                                      new Article2(
                                        slug,
                                        title,
                                        body,
                                        version,
                                        order,
                                        category,
                                        tags
                                      )
                                    );
                                  }
                                );
                              }
                            );
                          }
                        );
                      }
                    );
                  }
                );
              }
            );
          }
        )
      ),
      (items) => {
        return field(
          "next",
          optional(
            map3(
              string2,
              (raw) => {
                let $ = cursor(raw);
                let value2;
                if ($ instanceof Ok) {
                  value2 = $[0];
                } else {
                  throw makeError(
                    "let_assert",
                    FILEPATH,
                    "gen/out/article_list",
                    64,
                    "decoder",
                    "Pattern match failed, no pattern matched the value.",
                    {
                      value: $,
                      start: 1614,
                      end: 1648,
                      pattern_start: 1625,
                      pattern_end: 1634
                    }
                  );
                }
                return value2;
              }
            )
          ),
          (next) => {
            return success(new Page(items, next));
          }
        );
      }
    ),
    (page) => {
      return field(
        "counts",
        list2(
          then$(
            at(
              toList([0]),
              field(
                "name",
                string2,
                (name) => {
                  return success(new Category(name));
                }
              )
            ),
            (first) => {
              return map3(
                at(toList([1]), int2),
                (second) => {
                  return [first, second];
                }
              );
            }
          )
        ),
        (counts) => {
          return success(new Out(page, counts));
        }
      );
    }
  );
}

// public/build/dev/javascript/public/gen/live/article_create.mjs
var Args2 = class extends CustomType {
  constructor(slug, title, body, category, tags) {
    super();
    this.slug = slug;
    this.title = title;
    this.body = body;
    this.category = category;
    this.tags = tags;
  }
};
var Slug2 = class extends CustomType {
};
var Field$Slug$const2 = new Slug2();
var Title = class extends CustomType {
};
var Field$Title$const = new Title();
var Body = class extends CustomType {
};
var Field$Body$const = new Body();
var Category2 = class extends CustomType {
};
var Field$Category$const = new Category2();
var Tags = class extends CustomType {
};
var Field$Tags$const = new Tags();
var Invalid3 = class extends CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
};
var Failed2 = class extends CustomType {
};
var Error$Failed$const2 = new Failed2();
function init2(given) {
  return [
    new State(
      new Args2("", "", "", "", ""),
      given,
      Option$None$const,
      false
    ),
    none()
  ];
}
function reload_page() {
  return emit2("yumemi-done", null$());
}
function send4(args) {
  return from2(
    (dispatch2) => {
      return send2(
        "POST",
        "/api/articles",
        object2(
          toList([
            ["slug", string3(args.slug)],
            ["title", string3(args.title)],
            ["body", string3(args.body)],
            ["category", string3(args.category)],
            ["tags", string3(args.tags)]
          ])
        ),
        (value2) => {
          let $ = run(value2, decoder2());
          if ($ instanceof Ok) {
            let out = $[0];
            return dispatch2(new Done(new Ok(out)));
          } else {
            return dispatch2(new Done(new Error(Error$Failed$const2)));
          }
        },
        (_) => {
          return dispatch2(new Done(new Error(Error$Failed$const2)));
        }
      );
    }
  );
}
function validate_field2(field2, raw, constraint) {
  let $ = validate(raw, constraint);
  if ($ instanceof Ok) {
    return List$Empty$const;
  } else {
    return toList([[field2, "invalid"]]);
  }
}
function validate3(model) {
  let errors = flatten(
    toList([
      validate_field2(
        Field$Slug$const2,
        model.args.slug,
        new Pattern(1, 64, "^[a-z0-9]+(-[a-z0-9]+)*$")
      ),
      validate_field2(
        Field$Title$const,
        model.args.title,
        new Text2(1, 120)
      ),
      validate_field2(
        Field$Body$const,
        model.args.body,
        Spec$Markdown$const
      )
    ])
  );
  if (errors instanceof Empty) {
    return new Ok(model.args);
  } else {
    return new Error(errors);
  }
}
function update3(model, msg) {
  if (msg instanceof Set2) {
    let $ = msg[0];
    if ($ instanceof Slug2) {
      let value2 = msg[1];
      return [
        new State(
          (() => {
            let _record = model.args;
            return new Args2(
              value2,
              _record.title,
              _record.body,
              _record.category,
              _record.tags
            );
          })(),
          model.given,
          model.last,
          model.waiting
        ),
        none()
      ];
    } else if ($ instanceof Title) {
      let value2 = msg[1];
      return [
        new State(
          (() => {
            let _record = model.args;
            return new Args2(
              _record.slug,
              value2,
              _record.body,
              _record.category,
              _record.tags
            );
          })(),
          model.given,
          model.last,
          model.waiting
        ),
        none()
      ];
    } else if ($ instanceof Body) {
      let value2 = msg[1];
      return [
        new State(
          (() => {
            let _record = model.args;
            return new Args2(
              _record.slug,
              _record.title,
              value2,
              _record.category,
              _record.tags
            );
          })(),
          model.given,
          model.last,
          model.waiting
        ),
        none()
      ];
    } else if ($ instanceof Category2) {
      let value2 = msg[1];
      return [
        new State(
          (() => {
            let _record = model.args;
            return new Args2(
              _record.slug,
              _record.title,
              _record.body,
              value2,
              _record.tags
            );
          })(),
          model.given,
          model.last,
          model.waiting
        ),
        none()
      ];
    } else {
      let value2 = msg[1];
      return [
        new State(
          (() => {
            let _record = model.args;
            return new Args2(
              _record.slug,
              _record.title,
              _record.body,
              _record.category,
              value2
            );
          })(),
          model.given,
          model.last,
          model.waiting
        ),
        none()
      ];
    }
  } else if (msg instanceof Send) {
    let $ = model.waiting;
    if ($) {
      return [model, none()];
    } else {
      let $1 = validate3(model);
      if ($1 instanceof Ok) {
        let args = $1[0];
        return [
          new State(model.args, model.given, model.last, true),
          send4(args)
        ];
      } else {
        let errors = $1[0];
        return [
          new State(
            model.args,
            model.given,
            new Some(new Error(new Invalid3(errors))),
            model.waiting
          ),
          none()
        ];
      }
    }
  } else if (msg instanceof Given) {
    let given = msg[0];
    return [
      new State(model.args, given, model.last, model.waiting),
      none()
    ];
  } else {
    let result = msg[0];
    let next = new State(model.args, model.given, new Some(result), false);
    if (result instanceof Ok) {
      return [next, reload_page()];
    } else {
      return [next, none()];
    }
  }
}

// public/build/dev/javascript/public/components/pick_tag.mjs
function view2(it) {
  return div_(
    List$Empty$const,
    toList([
      select_(
        toList([
          on_change(
            (value2) => {
              return new Set2(
                Field$Tags$const,
                value2
              );
            }
          )
        ]),
        map2(
          it.given.counts,
          (item) => {
            let category = item[0];
            return option_(
              toList([value(category.name)]),
              toList([text4(category.name)])
            );
          }
        )
      ),
      button_(
        toList([
          on_click(Event$Send$const),
          disabled(it.waiting)
        ]),
        toList([text4("\u30BF\u30B0\u3092\u4FDD\u5B58")])
      )
    ])
  );
}
function app2() {
  return component(
    init2,
    update3,
    view2,
    toList([
      on_attribute_change(
        "slug",
        (value2) => {
          return new Ok(
            new Set2(Field$Slug$const2, value2)
          );
        }
      ),
      on_attribute_change(
        "title",
        (value2) => {
          return new Ok(
            new Set2(Field$Title$const, value2)
          );
        }
      ),
      on_attribute_change(
        "body",
        (value2) => {
          return new Ok(
            new Set2(Field$Body$const, value2)
          );
        }
      ),
      on_attribute_change(
        "category",
        (value2) => {
          return new Ok(
            new Set2(Field$Category$const, value2)
          );
        }
      ),
      on_attribute_change(
        "selected",
        (value2) => {
          return new Ok(
            new Set2(Field$Tags$const, value2)
          );
        }
      )
    ])
  );
}

// client-entry.mjs
function registerWithGiven(app3, decoder4, tag) {
  const element5 = document.querySelector(tag);
  const raw = element5?.getAttribute("data-yumemi-given");
  if (raw === null) return;
  let given;
  try {
    const decoded = run(JSON.parse(raw), decoder4());
    if (!Result$isOk(decoded)) return;
    given = Result$Ok$0(decoded);
  } catch (_error) {
    return;
  }
  make_component({ ...app3, init: () => app3.init(given) }, tag);
}
function listenReload(tag) {
  document.querySelectorAll(tag).forEach((element5) => {
    element5.addEventListener("yumemi-done", () => {
      globalThis.location.assign(globalThis.location.href);
    });
  });
}
make_component(app(), "like-button");
registerWithGiven(app2(), decoder3, "pick-tag");
listenReload("pick-tag");
