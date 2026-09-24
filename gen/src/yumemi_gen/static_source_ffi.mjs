import { toList } from "../gleam.mjs";

const fields = ["connector", "host", "name", "information", "purpose", "side"];

export function parse_external_hosts(source) {
  try {
    const next = tokenizer(source);
    let lookahead;
    let hasLookahead = false;

    function peek() {
      if (!hasLookahead) {
        lookahead = next();
        hasLookahead = true;
      }
      return lookahead;
    }
    function take() {
      const value = peek();
      hasLookahead = false;
      return value;
    }
    function expect(value) {
      const token = take();
      if (token?.value !== value) throw new Error("unexpected token");
    }
    function identifier() {
      const token = take();
      if (token?.kind !== "identifier") throw new Error("expected identifier");
      return token.value;
    }
    function literal() {
      const token = take();
      if (token?.kind !== "string") throw new Error("expected string literal");
      return token.value;
    }

    expect("export");
    expect("const");
    expect("EXTERNAL_HOSTS");
    expect("=");
    expect("Object");
    expect(".");
    expect("freeze");
    expect("(");
    expect("[");

    const values = ["ok"];
    if (peek()?.value !== "]") {
      while (true) {
        expect("{");
        const record = Object.create(null);
        while (peek()?.value !== "}") {
          const key = identifier();
          if (!fields.includes(key) || Object.hasOwn(record, key)) {
            throw new Error("unexpected or duplicate field");
          }
          expect(":");
          record[key] = literal();
          if (peek()?.value === "}") break;
          expect(",");
        }
        expect("}");
        if (fields.some((field) => !Object.hasOwn(record, field))) {
          throw new Error("missing field");
        }
        if (record.side !== "server" && record.side !== "browser") {
          throw new Error("unknown side");
        }
        values.push(...fields.map((field) => record[field]));
        if (peek()?.value === "]") break;
        expect(",");
        if (peek()?.value === "]") break;
      }
    }
    expect("]");
    expect(")");
    if (peek()?.value === ";") take();
    return toList(values);
  } catch {
    return toList([]);
  }
}

function tokenizer(source) {
  let offset = 0;

  function skipTrivia() {
    while (offset < source.length) {
      if (isWhitespace(source[offset])) {
        offset += 1;
      } else if (source.startsWith("//", offset)) {
        offset += 2;
        while (offset < source.length && source[offset] !== "\n" && source[offset] !== "\r") {
          offset += 1;
        }
        if (offset < source.length && source[offset] === "\r") offset += 1;
        if (offset < source.length && source[offset] === "\n") offset += 1;
      } else if (source.startsWith("/*", offset)) {
        const end = source.indexOf("*/", offset + 2);
        if (end < 0) throw new Error("unterminated comment");
        offset = end + 2;
      } else {
        break;
      }
    }
  }

  return function next() {
    skipTrivia();
    if (offset >= source.length) return null;
    const start = offset;
    const current = source[offset];

    if (current === "'" || current === '"') {
      const quote = current;
      offset += 1;
      let value = "";
      while (offset < source.length) {
        const character = source[offset++];
        if (character === quote) return { kind: "string", value };
        if (character === "\n" || character === "\r") {
          throw new Error("newline in string literal");
        }
        if (character !== "\\") {
          value += character;
          continue;
        }
        if (offset >= source.length) throw new Error("unfinished escape");
        const escaped = source[offset++];
        switch (escaped) {
          case "\\": value += "\\"; break;
          case "'": value += "'"; break;
          case '"': value += '"'; break;
          case "n": value += "\n"; break;
          case "r": value += "\r"; break;
          case "t": value += "\t"; break;
          case "b": value += "\b"; break;
          case "f": value += "\f"; break;
          default: throw new Error("unsupported escape");
        }
      }
      throw new Error("unterminated string literal");
    }

    if (isIdentifierStart(current)) {
      offset += 1;
      while (offset < source.length && isIdentifierPart(source[offset])) {
        offset += 1;
      }
      return { kind: "identifier", value: source.slice(start, offset) };
    }

    if ("=.()[]{}:;,".includes(current)) {
      offset += 1;
      return { kind: "punctuation", value: current };
    }
    throw new Error("unsupported token");
  };
}

function isWhitespace(character) {
  return character === " "
    || character === "\t"
    || character === "\n"
    || character === "\r"
    || character === "\f"
    || character === "\v"
    || character === "\u00a0";
}

function isIdentifierStart(character) {
  return (character >= "A" && character <= "Z")
    || (character >= "a" && character <= "z")
    || character === "_"
    || character === "$";
}

function isIdentifierPart(character) {
  return isIdentifierStart(character) || (character >= "0" && character <= "9");
}
