export function validDate(raw) {
  return /^\d{4}-\d{2}-\d{2}$/.test(raw) && Number.isFinite(Date.parse(raw)) && new Date(raw).toISOString().slice(0,10) === raw;
}
export const validTime = raw => /^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d{1,6})?)?$/.test(raw);
export const validDatetime = raw => /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(raw) && validDate(raw.slice(0,10)) && Number.isFinite(Date.parse(raw));
export const addDays=(value,days)=>new Date(Date.parse(value)+days*86400000).toISOString();
export function toDate(value) {
  const date = new Date(Date.parse(value));
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const fields = Object.fromEntries(parts.filter(part => part.type !== "literal").map(part => [part.type, part.value]));
  return `${fields.year}-${fields.month}-${fields.day}`;
}
export const dateLe = (left, right) => left <= right;
export const datetimeLt = (left, right) => Date.parse(left) < Date.parse(right);
export const datetimeLe = (left, right) => Date.parse(left) <= Date.parse(right);
export const quarterAligned = value => {
  const time = Date.parse(value);
  if (!Number.isFinite(time)) return false;
  const date = new Date(time);
  const fraction = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:(?:\d{2})(?:\.(\d+))?/.exec(value)?.[1];
  const zeroFraction = fraction === undefined || /^0+$/.test(fraction);
  return zeroFraction && date.getUTCSeconds() === 0 && date.getUTCMilliseconds() === 0 && time % (15 * 60 * 1000) === 0;
};
