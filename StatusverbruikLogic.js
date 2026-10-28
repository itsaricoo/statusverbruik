.pragma library
// Status Verbruik voor rooted Toons - pure rekenlogica (geen QML-afhankelijkheden).
// Eenheden uit de lokale REST-service (hdrv_p1): elektriciteit in Wh, gas in liter.

var MONTHS = ["januari", "februari", "maart", "april", "mei", "juni", "juli",
              "augustus", "september", "oktober", "november", "december"];

// EIGEN BENADERING (niet de verdeling van Quby, die is niet bekend): aandeel per maand van het jaarverbruik.
var PROFILES = {
	elec: [0.092, 0.082, 0.086, 0.079, 0.077, 0.074, 0.075, 0.077, 0.079, 0.085, 0.090, 0.104],
	gas:  [0.185, 0.150, 0.120, 0.075, 0.040, 0.020, 0.015, 0.015, 0.030, 0.075, 0.125, 0.150]
};

function defaultSettings() {
	return {
		version: 1,
		hasElec: true, dualTariff: false, hasGas: true,
		profile: "season",            // "season" | "flat"
		elecUsage: 0, elecLowUsage: 0, // kWh per jaar (normaal / laag)
		elecPrice: 0, elecLowPrice: 0, // euro per kWh
		gasUsage: 0, gasPrice: 0       // m3 per jaar, euro per m3
	};
}

// Geeft een getal >= 0, anders NaN. Accepteert komma als decimaalteken.
function num(v) {
	if (typeof v === "number") return (isFinite(v) && v >= 0) ? v : NaN;
	var s = String(v === undefined || v === null ? "" : v).replace(/\s/g, "").replace(",", ".");
	if (s === "" || !/^\d*\.?\d+$|^\d+\.?$/.test(s)) return NaN;
	var n = parseFloat(s);
	return (isFinite(n) && n >= 0) ? n : NaN;
}

function sanitizeSettings(obj) {
	var d = defaultSettings(), o = (obj && typeof obj === "object") ? obj : {};
	var numKeys = ["elecUsage", "elecLowUsage", "elecPrice", "elecLowPrice", "gasUsage", "gasPrice"];
	var boolKeys = ["hasElec", "dualTariff", "hasGas"];
	for (var i = 0; i < numKeys.length; i++) {
		var n = num(o[numKeys[i]]);
		d[numKeys[i]] = isNaN(n) ? 0 : n;
	}
	for (var j = 0; j < boolKeys.length; j++)
		if (typeof o[boolKeys[j]] === "boolean") d[boolKeys[j]] = o[boolKeys[j]];
	d.profile = (o.profile === "flat") ? "flat" : "season";
	return d;
}

function isConfigured(s) {
	if (!s) return false;
	return (s.hasElec && (s.elecUsage + (s.dualTariff ? s.elecLowUsage : 0)) > 0) || (s.hasGas && s.gasUsage > 0);
}

function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate(); }
function daysInYear(y) { return ((y % 4 === 0 && y % 100 !== 0) || y % 400 === 0) ? 366 : 365; }
function pad2(n) { return (n < 10 ? "0" : "") + n; }

// Lokale ISO 8601-datum met UTC-offset, bv. 2026-10-01T00:00:00+02:00
function toISO(d) {
	var off = -d.getTimezoneOffset(), sign = off >= 0 ? "+" : "-";
	off = Math.abs(off);
	return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()) + "T" +
		pad2(d.getHours()) + ":" + pad2(d.getMinutes()) + ":" + pad2(d.getSeconds()) +
		sign + pad2(Math.floor(off / 60)) + ":" + pad2(off % 60);
}

function startOfDay(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0); }

// Aandeel (0..1) van het jaarverbruik dat in maand m (0-11) van jaar y valt.
function monthFraction(kind, y, m, profile) {
	if (profile === "flat") return daysInMonth(y, m) / daysInYear(y);
	var p = PROFILES[kind], sum = 0;
	for (var i = 0; i < 12; i++) sum += p[i];
	return p[m] / sum;
}

// Aandeel van de maand dat voorbij is (volledige dagen): verleden=1, toekomst=0, huidig=(dag-1)/dagen.
function progressFor(y, m, now) {
	var cur = now.getFullYear() * 12 + now.getMonth(), tgt = y * 12 + m;
	if (tgt < cur) return 1;
	if (tgt > cur) return 0;
	return (now.getDate() - 1) / daysInMonth(y, m);
}

// Tijdvak met volledige dagen voor de maand; null als er nog geen volledige dag is.
function rangeForMonth(y, m, now) {
	var from = new Date(y, m, 1, 0, 0, 0, 0);
	var to = new Date(y, m + 1, 1, 0, 0, 0, 0);
	var today = startOfDay(now);
	if (today < to) to = today;
	return (to > from) ? {from: from, to: to} : null;
}

// Standaard maand om te tonen: op de 1e van de maand de vorige maand (net als het origineel).
function defaultMonth(now) {
	var y = now.getFullYear(), m = now.getMonth();
	if (now.getDate() === 1) { m--; if (m < 0) { m = 11; y--; } }
	return {year: y, month: m};
}

// Som van body.data[i].value; NaN bij onbruikbaar antwoord of ontbrekende waarden.
function sumData(body, expectedCount) {
	if (!body || !Array.isArray(body.data)) return NaN;
	if (expectedCount !== undefined && body.data.length !== expectedCount) return NaN;
	var sum = 0;
	for (var i = 0; i < body.data.length; i++) {
		var v = body.data[i] ? body.data[i].value : undefined;
		if (v === undefined || v === null) continue; // nog geen meting in dit interval
		v = Number(v);
		if (!isFinite(v)) return NaN;
		sum += v;
	}
	return sum;
}

// ---------- opmaak (Nederlands) ----------
function fmtNum(n, dec) {
	var s = Math.abs(n).toFixed(dec === undefined ? 0 : dec).split(".");
	s[0] = s[0].replace(/\B(?=(\d{3})+(?!\d))/g, ".");
	return (n < 0 ? "-" : "") + s.join(",");
}
function fmtEuro(n) { return "\u20ac " + fmtNum(n, Math.abs(n) < 10 && Math.abs(n) % 1 !== 0 ? 2 : 0); }

// ---------- berekening per energiesoort ----------
// real: {normal, low} in kWh voor elec, {normal} in m3 voor gas. fracSum: aandeel dat zou zijn verbruikt tot nu.
function energyResult(s, kind, fracSum, fullFrac, real) {
	var isElec = kind === "elec";
	var yN = isElec ? s.elecUsage : s.gasUsage;
	var yL = (isElec && s.dualTariff) ? s.elecLowUsage : 0;
	var pN = isElec ? s.elecPrice : s.gasPrice;
	var pL = isElec ? s.elecLowPrice : 0;
	var rN = real.normal || 0, rL = (isElec && s.dualTariff) ? (real.low || 0) : 0;
	var r = {
		kind: kind,
		title: isElec ? "Stroom" : "Gas",
		unit: isElec ? "kWh" : "m\u00b3",
		decimals: 0,
		realUsage: rN + rL,
		targetUsage: (yN + yL) * fracSum,
		fullTargetUsage: (yN + yL) * fullFrac,
		realCost: rN * pN + rL * pL,
		targetCost: yN * fracSum * pN + yL * fracSum * pL,
		fullTargetCost: yN * fullFrac * pN + yL * fullFrac * pL,
		costValid: pN > 0 && (!(isElec && s.dualTariff) || pL > 0 || yL === 0),
		hasEstimate: (yN + yL) > 0
	};
	r.diffUsage = r.targetUsage - r.realUsage;   // >0 = minder dan geschat (goed)
	r.diffCost = r.targetCost - r.realCost;
	r.good = r.diffUsage >= 0;
	return r;
}

function cardFromResult(r) {
	var u = " " + r.unit;
	var c = {
		kind: r.kind, title: r.title, good: r.good, hasEstimate: r.hasEstimate, costValid: r.costValid,
		realText: fmtNum(r.realUsage, r.decimals) + u + (r.costValid ? "  \u00b7  " + fmtEuro(r.realCost) : ""),
		targetText: fmtNum(r.targetUsage, r.decimals) + u + (r.costValid ? "  \u00b7  " + fmtEuro(r.targetCost) : ""),
		fullText: fmtNum(r.fullTargetUsage, r.decimals) + u + (r.costValid ? "  \u00b7  " + fmtEuro(r.fullTargetCost) : ""),
		ratio: r.targetUsage > 0 ? r.realUsage / r.targetUsage : 0
	};
	var d = Math.abs(r.diffUsage);
	if (!r.hasEstimate) c.diffText = "Geen jaarverbruik ingevuld";
	else if (r.targetUsage <= 0) c.diffText = "Nog geen volledige dag gemeten";
	else if (Math.round(d) === 0) c.diffText = "Zoals geschat";
	else if (r.costValid) c.diffText = fmtEuro(Math.abs(r.diffCost)) + (r.good ? " minder" : " meer") + " dan geschat";
	else c.diffText = fmtNum(d, r.decimals) + u + (r.good ? " minder" : " meer") + " dan geschat";
	return c;
}

// res: {elecN:{ok,value}, elecL:{ok,value}, gas:{ok,value}} met value in Wh / liter.
// fracs: {elec:{sum,full}, gas:{sum,full}}. Geeft {status, message, cards, total}.
function buildResult(s, fracs, res, hasProgress) {
	var out = {status: "ok", message: "", cards: [], total: null};
	if (!isConfigured(s)) { out.status = "noconfig"; out.message = "Vul eerst uw jaarverbruik in."; return out; }
	if (!hasProgress) { out.status = "nodata"; out.message = "Er is nog geen volledige dag gemeten in deze periode."; }
	var results = [], failed = [];
	if (s.hasElec) {
		var e = res.elecN, l = res.elecL;
		if (!e || !e.ok || (s.dualTariff && (!l || !l.ok))) failed.push("stroom");
		else results.push(energyResult(s, "elec", fracs.elec.sum, fracs.elec.full,
			{normal: e.value / 1000, low: (s.dualTariff && l) ? l.value / 1000 : 0}));
	}
	if (s.hasGas) {
		var g = res.gas;
		if (!g || !g.ok) failed.push("gas");
		else results.push(energyResult(s, "gas", fracs.gas.sum, fracs.gas.full, {normal: g.value / 1000}));
	}
	if (failed.length) {
		out.status = "error";
		out.message = "Kon het verbruik van " + failed.join(" en ") + " niet ophalen van de Toon.";
	}
	var allCost = results.length > 0, diffCost = 0, diffUsageGood = true, any = false;
	for (var i = 0; i < results.length; i++) {
		out.cards.push(cardFromResult(results[i]));
		if (!results[i].hasEstimate) continue;
		any = true;
		if (!results[i].costValid) allCost = false;
		diffCost += results[i].diffCost;
		if (!results[i].good) diffUsageGood = false;
	}
	if (any && allCost) {
		var rd = Math.round(diffCost);
		out.total = {kind: "cost", good: diffCost >= 0, diffCost: diffCost,
			short: rd === 0 ? "Zoals geschat" : fmtEuro(Math.abs(diffCost)) + (diffCost > 0 ? " minder" : " meer"),
			text: rd === 0 ? "Precies zoals geschat" : fmtEuro(Math.abs(diffCost)) + (diffCost > 0 ? " minder" : " meer") + " dan geschat"};
	} else if (any) {
		out.total = {kind: "usage", good: diffUsageGood, diffCost: 0,
			short: diffUsageGood ? "Minder verbruikt" : "Meer verbruikt",
			text: "Vul uw tarieven in om de kosten te zien"};
	}
	return out;
}

// Aandelen voor een maand of (tot nu) voor een heel jaar.
function monthFracs(s, y, m, now) {
	var p = progressFor(y, m, now);
	var fe = monthFraction("elec", y, m, s.profile), fg = monthFraction("gas", y, m, s.profile);
	return {progress: p, elec: {sum: fe * p, full: fe}, gas: {sum: fg * p, full: fg}};
}
function yearFracs(s, y, now) {
	var se = 0, sg = 0, any = 0;
	for (var m = 0; m < 12; m++) {
		var p = progressFor(y, m, now);
		se += monthFraction("elec", y, m, s.profile) * p;
		sg += monthFraction("gas", y, m, s.profile) * p;
		any += p;
	}
	return {progress: any, elec: {sum: se, full: 1}, gas: {sum: sg, full: 1}};
}
