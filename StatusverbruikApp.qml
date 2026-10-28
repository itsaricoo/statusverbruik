//
// Status Verbruik voor rooted Toons
// Vergelijkt het werkelijke verbruik (lokale data van de Toon) met een schatting op basis van
// het jaarverbruik dat de gebruiker zelf invult. Werkt zonder Quby/Eneco-cloud.
//
import QtQuick 2.1
import qb.components 1.0
import qb.base 1.0
import qb.energyinsights 1.0 as EnergyInsights

import "StatusverbruikLogic.js" as Logic

App {
	id: statusverbruikApp

	property url tileUrl: "StatusverbruikTile.qml"
	property url screenUrl: "StatusverbruikScreen.qml"
	property url settingsScreenUrl: "StatusverbruikSettingsScreen.qml"
	// Icoon van de originele (stock) Status Usage-app; staat op de Toon zelf in drawables-base.rcc
	property url thumbIconUrl: "qrc://apps/statusUsage/drawables/tile_total_thumb.svg"
	property string settingsPath: "file:///mnt/data/tsc/statusverbruik.userSettings.json"

	property var userSettings: Logic.defaultSettings()
	property bool configured: Logic.isConfigured(userSettings)

	// Voor de tile
	property string tileStatus: "loading"   // loading | noconfig | nodata | error | ok
	property string tileLine1: "Laden..."
	property string tileLine2: ""
	property bool tileGood: true

	property double refreshStarted: 0
	property int refreshGen: 0
	property int retryCount: 0
	property bool settingsLoaded: false
	property var pendingSaveFinish: null

	function init() {
		registry.registerWidget("screen", screenUrl, this);
		registry.registerWidget("screen", settingsScreenUrl, this);
		registry.registerWidget("tile", tileUrl, this, null, {thumbLabel: "Status verbruik",
			thumbIcon: thumbIconUrl, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10,
			baseTileSolarWeight: 10, thumbIconVAlignment: "center"});
	}

	Component.onCompleted: {
		// instellingen laden bij Component.onCompleted (aanbevolen door TSC) en niet in init()
		loadSettings();
	}

	// ---------- instellingen (XMLHttpRequest, zoals andere TSC-apps; geen FileIO nodig) ----------
	function loadSettings() {
		var req = new XMLHttpRequest();
		req.onreadystatechange = function () {
			if (req.readyState !== XMLHttpRequest.DONE) return;
			try {
				if (req.responseText && req.responseText.length > 1)
					userSettings = Logic.sanitizeSettings(JSON.parse(req.responseText));
			} catch (e) {
				console.log("Statusverbruik: instellingen lezen mislukt, standaardwaarden gebruikt:", e);
			}
			settingsLoaded = true;
			refreshTile();
		};
		req.open("GET", settingsPath, true);
		req.send();
	}

	// Schrijft het bestand, leest het terug ter controle en roept cb({ok, message}) aan (altijd precies een keer).
	function saveSettings(obj, cb) {
		var clean = Logic.sanitizeSettings(obj);
		var text = JSON.stringify(clean);
		var done = false;

		function finish(ok, message) {
			if (done) return;
			done = true;
			saveGuard.stop();
			pendingSaveFinish = null;
			if (ok) {
				userSettings = clean;
				refreshStarted = 0;
				retryCount = 0;
				refreshTile();
			}
			if (typeof cb === "function") cb({ok: ok, message: message});
		}

		pendingSaveFinish = finish;
		saveGuard.restart();
		try {
			var put = new XMLHttpRequest();
			put.onreadystatechange = function () {
				if (put.readyState !== XMLHttpRequest.DONE) return;
				var get = new XMLHttpRequest();
				get.onreadystatechange = function () {
					if (get.readyState !== XMLHttpRequest.DONE) return;
					var ok = false;
					try {
						ok = JSON.stringify(Logic.sanitizeSettings(JSON.parse(get.responseText))) === text;
					} catch (e2) {
						ok = false;
					}
					finish(ok, ok ? "Opgeslagen." : "Opslaan niet bevestigd: kan /mnt/data/tsc niet schrijven.");
				};
				get.open("GET", settingsPath, true);
				get.send();
			};
			put.open("PUT", settingsPath);
			put.send(text);
		} catch (e) {
			finish(false, "Opslaan mislukt: " + e);
		}
	}

	// ---------- data ophalen ----------
	// interval: "days" of "months"; range {from,to}; done(res) met res[key] = {ok, value}
	function runJobs(jobs, interval, range, expectedCount, done) {
		var res = {};
		var pending = jobs.length;
		if (pending === 0) { done(res); return; }

		function runJob(job) {
			EnergyInsights.Functions.requestData(function (success, body) {
				var v = success ? Logic.sumData(body, expectedCount) : NaN;
				if (isNaN(v))
					console.log("Statusverbruik: onbruikbaar antwoord voor", job.key, interval, "verwacht aantal:", expectedCount,
								"success:", success, "body:", String(JSON.stringify(body)).substring(0, 300));
				res[job.key] = {ok: !isNaN(v), value: v};
				pending--;
				if (pending === 0) done(res);
			}, job.utility, "consumption", "quantity", job.tariff, false, interval,
			   Logic.toISO(range.from), Logic.toISO(range.to));
		}
		for (var i = 0; i < jobs.length; i++) runJob(jobs[i]);
	}

	function buildJobs(s) {
		var jobs = [];
		if (s.hasElec) {
			jobs.push({key: "elecN", utility: "electricity", tariff: s.dualTariff ? "normal-tariff" : undefined});
			if (s.dualTariff) jobs.push({key: "elecL", utility: "electricity", tariff: "low-tariff"});
		}
		if (s.hasGas) jobs.push({key: "gas", utility: "gas", tariff: undefined});
		return jobs;
	}

	function zeroResults(jobs) {
		var res = {};
		for (var i = 0; i < jobs.length; i++) res[jobs[i].key] = {ok: true, value: 0};
		return res;
	}

	function finish(r, label, partial, cb) {
		r.periodLabel = label;
		r.partial = partial;
		cb(r);
	}

	// Maandoverzicht; cb(result)
	function computeMonth(y, m, cb) {
		var s = userSettings, now = new Date();
		if (!Logic.isConfigured(s)) { finish(Logic.buildResult(s, null, {}, false), "", false, cb); return; }
		var fr = Logic.monthFracs(s, y, m, now);
		var label = Logic.MONTHS[m] + " " + y;
		var partial = fr.progress < 1;
		var range = Logic.rangeForMonth(y, m, now);
		var jobs = buildJobs(s);
		if (!range) {
			finish(Logic.buildResult(s, fr, zeroResults(jobs), false), label, partial, cb);
			return;
		}
		runJobs(jobs, "days", range, undefined, function (res) {
			finish(Logic.buildResult(s, fr, res, fr.progress > 0), label, partial, cb);
		});
	}

	// Jaaroverzicht (tot nu voor het huidige jaar); cb(result)
	function computeYear(y, cb) {
		var s = userSettings, now = new Date();
		if (!Logic.isConfigured(s)) { finish(Logic.buildResult(s, null, {}, false), "", false, cb); return; }
		var fr = Logic.yearFracs(s, y, now);
		var partial = fr.progress < 12;
		var label = "" + y;
		var jobs = buildJobs(s);
		if (fr.progress <= 0) {
			finish(Logic.buildResult(s, fr, zeroResults(jobs), false), label, partial, cb);
			return;
		}
		var curIdx = (now.getFullYear() === y) ? now.getMonth() : (y < now.getFullYear() ? 12 : 0);
		var completed = {from: new Date(y, 0, 1), to: new Date(y, curIdx, 1)};
		var partialRange = (now.getFullYear() === y) ? Logic.rangeForMonth(y, now.getMonth(), now) : null;

		// stap 1: afgeronde maanden (interval months), stap 2: lopende maand (interval days)
		function withCompleted(resA) {
			if (!partialRange) { finish(Logic.buildResult(s, fr, resA, true), label, partial, cb); return; }
			runJobs(jobs, "days", partialRange, undefined, function (resB) {
				var merged = {};
				for (var k in resA) {
					var b = resB[k];
					merged[k] = {ok: !!(resA[k].ok && b && b.ok), value: resA[k].value + (b ? b.value : 0)};
				}
				finish(Logic.buildResult(s, fr, merged, true), label, partial, cb);
			});
		}
		if (curIdx === 0) withCompleted(zeroResults(jobs));
		else runJobs(jobs, "months", completed, curIdx, withCompleted);
	}

	// ---------- tile ----------
	function refreshTile() {
		if (!settingsLoaded) return;
		var nowMs = new Date().getTime();
		if (refreshStarted > 0 && nowMs - refreshStarted < 120000) return; // vorige ophaalactie loopt nog
		if (!configured) {
			tileStatus = "noconfig"; tileLine1 = "Jaarverbruik"; tileLine2 = "invullen"; tileGood = true;
			return;
		}
		refreshStarted = nowMs;
		var gen = ++refreshGen;
		var dm = Logic.defaultMonth(new Date());
		computeMonth(dm.year, dm.month, function (r) {
			if (gen !== refreshGen) return;   // verouderd antwoord (instellingen zijn intussen gewijzigd)
			refreshStarted = 0;
			tileStatus = r.status;
			if (r.status === "ok" && r.total) {
				tileLine1 = r.total.short;
				tileLine2 = "dan geschat" + (r.partial ? ", t/m nu" : "") + " (" + Logic.MONTHS[dm.month] + ")";
				tileGood = r.total.good;
				retryCount = 0;
			} else if (r.status === "error") {
				tileLine1 = "Geen gegevens"; tileLine2 = "Toon-data niet bereikbaar"; tileGood = true;
				// P1-driver is bij het opstarten soms nog niet gevonden: snel opnieuw proberen
				if (retryCount < 10) { retryCount++; retryTimer.restart(); }
			} else {
				tileLine1 = "Nog geen data"; tileLine2 = "wacht op volledige dag"; tileGood = true;
			}
		});
	}

	Timer {
		id: retryTimer
		interval: 60000
		repeat: false
		onTriggered: refreshTile()
	}

	// Vangnet: als de XHR-afhandeling bij opslaan nooit terugkomt, krijgt het scherm toch een melding
	Timer {
		id: saveGuard
		interval: 8000
		repeat: false
		onTriggered: {
			if (typeof pendingSaveFinish === "function")
				pendingSaveFinish(false, "Opslaan niet bevestigd (time-out).");
		}
	}

	Timer {
		id: refreshTimer
		interval: 900000  // 15 minuten
		repeat: true
		running: true
		onTriggered: refreshTile()
	}
}
