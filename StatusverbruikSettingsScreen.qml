import QtQuick 2.1
import qb.components 1.0

import "StatusverbruikLogic.js" as Logic

// Scherm waar de gebruiker het eigen jaarverbruik en de tarieven invult.
// Opzet volgens de TSC-apps (o.a. spotenergy): SingleLabel + OnOffToggle + qnumKeyboard.
Screen {
	id: svSettings
	screenTitle: "Jaarverbruik invullen"
	hasBackButton: false
	hasHomeButton: false
	hasCancelButton: true

	property StatusverbruikApp app

	// Het toetsenbord sluiten roept onShown opnieuw aan; zonder deze vlag worden ingevoerde
	// waarden dan overschreven met de opgeslagen instellingen (zelfde probleem als bij TSC-apps).
	property bool firstShown: true
	property bool saving: false

	// invoer als tekst (zoals getypt)
	property string fElecUsage: ""
	property string fElecLowUsage: ""
	property string fElecPrice: ""
	property string fElecLowPrice: ""
	property string fGasUsage: ""
	property string fGasPrice: ""

	property string statusText: ""
	property bool statusOk: true

	property int fieldW: isNxt ? 520 : 330
	property int fieldH: isNxt ? 45 : 35

	function svFmt(v) { return (v > 0) ? String(v).replace(".", ",") : ""; }

	onShown: {
		addCustomTopRightButton("Opslaan");
		if (firstShown) {
			var s = app.userSettings;
			fElecUsage = svFmt(s.elecUsage);
			fElecLowUsage = svFmt(s.elecLowUsage);
			fElecPrice = svFmt(s.elecPrice);
			fElecLowPrice = svFmt(s.elecLowPrice);
			fGasUsage = svFmt(s.gasUsage);
			fGasPrice = svFmt(s.gasPrice);
			elecToggle.isSwitchedOn = s.hasElec;
			dualToggle.isSwitchedOn = s.dualTariff;
			gasToggle.isSwitchedOn = s.hasGas;
			seasonToggle.isSwitchedOn = (s.profile === "season");
			statusText = "";
			saving = false;
			firstShown = false;
		}
	}

	onCanceled: {
		firstShown = true;   // bij annuleren mag het scherm de volgende keer weer met de opgeslagen waarden starten
	}

	onCustomButtonClicked: svSave()

	// ----- validatie voor het numerieke toetsenbord (text, isFinal) -> null of {content: melding} -----
	function usageValidate(text, isFinal) {
		if (isFinal) {
			var n = Logic.num(text);
			if (isNaN(n)) return {content: "Gebruik alleen cijfers en een komma"};
			if (n > 100000) return {content: "Onwaarschijnlijk hoog verbruik"};
		}
		return null;
	}

	function priceValidate(text, isFinal) {
		if (isFinal) {
			var n = Logic.num(text);
			if (isNaN(n)) return {content: "Gebruik alleen cijfers en een komma"};
			if (n > 5) return {content: "Tarief per kWh of m\u00b3, bijv. 0,32"};
		}
		return null;
	}

	// ----- callbacks van het toetsenbord; lege invoer (annuleren) wordt genegeerd, typ 0 om te wissen -----
	function clean(t) { return String(t).replace(/\s/g, ""); }
	function setElecUsage(t) { if (t) fElecUsage = clean(t); }
	function setElecLowUsage(t) { if (t) fElecLowUsage = clean(t); }
	function setElecPrice(t) { if (t) fElecPrice = clean(t); }
	function setElecLowPrice(t) { if (t) fElecLowPrice = clean(t); }
	function setGasUsage(t) { if (t) fGasUsage = clean(t); }
	function setGasPrice(t) { if (t) fGasPrice = clean(t); }

	function parseField(text, label, errors) {
		var t = String(text).replace(/\s/g, "");
		if (t === "") return 0;
		var n = Logic.num(t);
		if (isNaN(n)) { errors.push(label); return 0; }
		return n;
	}

	function svSave() {
		if (saving) return;
		var errors = [];
		var o = {
			hasElec: elecToggle.isSwitchedOn,
			dualTariff: dualToggle.isSwitchedOn,
			hasGas: gasToggle.isSwitchedOn,
			profile: seasonToggle.isSwitchedOn ? "season" : "flat",
			elecUsage: parseField(fElecUsage, "Stroom", errors),
			elecLowUsage: parseField(fElecLowUsage, "Stroom laag", errors),
			elecPrice: parseField(fElecPrice, "Tarief stroom", errors),
			elecLowPrice: parseField(fElecLowPrice, "Tarief stroom laag", errors),
			gasUsage: parseField(fGasUsage, "Gas", errors),
			gasPrice: parseField(fGasPrice, "Tarief gas", errors)
		};
		if (errors.length) {
			statusOk = false;
			statusText = "Ongeldige waarde bij: " + errors.join(", ") + ". Gebruik alleen cijfers en een komma (bijv. 3200 of 0,32).";
			return;
		}
		if (!Logic.isConfigured(Logic.sanitizeSettings(o))) {
			statusOk = false;
			statusText = "Vul minstens het jaarverbruik van stroom of gas in (en laat die soort aan staan).";
			return;
		}
		saving = true;
		statusOk = true;
		statusText = "Opslaan...";
		app.saveSettings(o, function (r) {
			saving = false;
			statusOk = r.ok;
			statusText = r.message;
			if (r.ok) {
				firstShown = true;   // een volgende keer weer met de opgeslagen waarden starten
				if (svSettings.showing) hide();
			}
		});
	}

	// ----- links: schakelaars -----
	Text {
		id: elecText
		x: 30
		y: 14
		width: 190
		font { family: qfont.semiBold.name; pixelSize: 16 }
		text: "Stroom meenemen"
	}
	OnOffToggle {
		id: elecToggle
		height: 36
		anchors { left: elecText.right; leftMargin: 10; verticalCenter: elecText.verticalCenter }
		leftIsSwitchedOn: false
	}

	Text {
		id: dualText
		width: 190
		anchors { left: elecText.left; top: elecText.bottom; topMargin: 30 }
		font { family: qfont.semiBold.name; pixelSize: 16 }
		text: "Dubbel tarief"
	}
	OnOffToggle {
		id: dualToggle
		height: 36
		anchors { left: elecToggle.left; verticalCenter: dualText.verticalCenter }
		leftIsSwitchedOn: false
	}

	Text {
		id: gasText
		width: 190
		anchors { left: elecText.left; top: dualText.bottom; topMargin: 30 }
		font { family: qfont.semiBold.name; pixelSize: 16 }
		text: "Gas meenemen"
	}
	OnOffToggle {
		id: gasToggle
		height: 36
		anchors { left: elecToggle.left; verticalCenter: gasText.verticalCenter }
		leftIsSwitchedOn: false
	}

	Text {
		id: seasonText
		width: 190
		anchors { left: elecText.left; top: gasText.bottom; topMargin: 30 }
		font { family: qfont.semiBold.name; pixelSize: 16 }
		text: "Seizoensverdeling"
	}
	OnOffToggle {
		id: seasonToggle
		height: 36
		anchors { left: elecToggle.left; verticalCenter: seasonText.verticalCenter }
		leftIsSwitchedOn: false
	}

	// ----- rechts: waarden -----
	Column {
		id: fields
		spacing: 10
		anchors { left: elecToggle.right; leftMargin: 30; top: elecText.top }

		SingleLabel {
			width: fieldW; height: fieldH
			visible: elecToggle.isSwitchedOn
			leftText: dualToggle.isSwitchedOn ? "Stroom normaal (kWh/jaar)" : "Stroom (kWh/jaar)"
			rightText: fElecUsage
			onClicked: qnumKeyboard.open("Jaarverbruik stroom", fElecUsage, "kWh", 1, setElecUsage, usageValidate)
		}
		SingleLabel {
			width: fieldW; height: fieldH
			visible: elecToggle.isSwitchedOn && dualToggle.isSwitchedOn
			leftText: "Stroom laag (kWh/jaar)"
			rightText: fElecLowUsage
			onClicked: qnumKeyboard.open("Jaarverbruik stroom laag tarief", fElecLowUsage, "kWh", 1, setElecLowUsage, usageValidate)
		}
		SingleLabel {
			width: fieldW; height: fieldH
			visible: elecToggle.isSwitchedOn
			leftText: dualToggle.isSwitchedOn ? "Tarief normaal (\u20ac/kWh)" : "Tarief stroom (\u20ac/kWh)"
			rightText: fElecPrice
			onClicked: qnumKeyboard.open("Tarief stroom (incl. btw)", fElecPrice, "Euro", 1, setElecPrice, priceValidate)
		}
		SingleLabel {
			width: fieldW; height: fieldH
			visible: elecToggle.isSwitchedOn && dualToggle.isSwitchedOn
			leftText: "Tarief laag (\u20ac/kWh)"
			rightText: fElecLowPrice
			onClicked: qnumKeyboard.open("Tarief stroom laag (incl. btw)", fElecLowPrice, "Euro", 1, setElecLowPrice, priceValidate)
		}
		SingleLabel {
			width: fieldW; height: fieldH
			visible: gasToggle.isSwitchedOn
			leftText: "Gas (m\u00b3/jaar)"
			rightText: fGasUsage
			onClicked: qnumKeyboard.open("Jaarverbruik gas", fGasUsage, "m\u00b3", 1, setGasUsage, usageValidate)
		}
		SingleLabel {
			width: fieldW; height: fieldH
			visible: gasToggle.isSwitchedOn
			leftText: "Tarief gas (\u20ac/m\u00b3)"
			rightText: fGasPrice
			onClicked: qnumKeyboard.open("Tarief gas (incl. btw)", fGasPrice, "Euro", 1, setGasPrice, priceValidate)
		}
	}

	Text {
		id: infoText
		anchors {
			left: parent.left; leftMargin: 30
			right: parent.right; rightMargin: 30
			bottom: statusLine.top; bottomMargin: 6
		}
		wrapMode: Text.WordWrap
		font { family: qfont.regular.name; pixelSize: isNxt ? 16 : 13 }
		color: "#555555"
		text: "Jaarverbruik en tarieven vindt u op uw jaarnota. Typ 0 om een veld leeg te maken. Seizoensverdeling = meer verbruik in de winter (vooral gas); uit = elke dag evenveel."
	}

	Text {
		id: statusLine
		anchors {
			left: parent.left; leftMargin: 30
			right: parent.right; rightMargin: 30
			bottom: parent.bottom; bottomMargin: 10
		}
		wrapMode: Text.WordWrap
		font { family: qfont.semiBold.name; pixelSize: isNxt ? 18 : 14 }
		color: statusOk ? "#2e7d32" : "#c62828"
		text: statusText
	}
}
