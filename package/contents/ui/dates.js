.pragma library

// Deadlines are days, not minutes: a card is due "on Friday", so a deadline is
// stored as a plain "YYYY-MM-DD" string. No timezone rides along with it, which
// is what makes a board keep the day it was given after a machine moves.

function pad(n) {
    return (n < 10 ? "0" : "") + n;
}

function toIso(d) {
    if (!d || isNaN(d.getTime())) return "";
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
}

// Local midnight, so day arithmetic never straddles a DST hour.
function parse(iso) {
    if (typeof iso !== "string") return null;
    var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso.trim());
    if (!m) return null;
    var y = parseInt(m[1], 10), mo = parseInt(m[2], 10) - 1, da = parseInt(m[3], 10);
    var d = new Date(y, mo, da);
    // Date rolls 2026-02-31 over into March rather than failing, so a parse that
    // came back as a different day was never a real date.
    if (d.getFullYear() !== y || d.getMonth() !== mo || d.getDate() !== da) return null;
    return d;
}

function isValid(iso) {
    return parse(iso) !== null;
}

function today() {
    var n = new Date();
    return new Date(n.getFullYear(), n.getMonth(), n.getDate());
}

function addDays(d, n) {
    var out = new Date(d.getFullYear(), d.getMonth(), d.getDate());
    out.setDate(out.getDate() + n);
    return out;
}

// Whole days from today: 0 today, negative once the day has passed, NaN when the
// card carries no deadline. Rounded because a DST day is 23 or 25 hours long.
function daysUntil(iso) {
    var d = parse(iso);
    if (!d) return NaN;
    return Math.round((d.getTime() - today().getTime()) / 86400000);
}

// The stored form of the day `n` days from today; what the quick rows pick.
function shift(n) {
    return toIso(addDays(today(), n));
}

function sameDay(a, b) {
    return !!a && !!b && a.getFullYear() === b.getFullYear()
           && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

// First cell of a month grid: the start of the week that holds the 1st, so the
// grid always begins on the locale's first weekday and never on a stray Monday.
function gridStart(year, month, firstDayOfWeek) {
    var first = new Date(year, month, 1);
    var offset = (first.getDay() - firstDayOfWeek + 7) % 7;
    return addDays(first, -offset);
}
