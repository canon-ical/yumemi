export function replace_commas_with_spaces(source, offsets) {
  if (offsets === "") return source;
  const codeUnits = source.split("");
  for (const rawOffset of offsets.split(",")) {
    const offset = Number(rawOffset);
    if (codeUnits[offset] === ",") codeUnits[offset] = " ";
  }
  return codeUnits.join("");
}
