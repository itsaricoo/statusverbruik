import QtQuick 2.1
import qb.components 1.0
import BasicUIControls 1.0   // bevat ControlGroup (zoals in het stock-scherm)

import "StatusverbruikLogic.js" as Logic

Screen {
	id: svScreen
	screenTitle: "Status verbruik"

	property StatusverbruikApp app

	property int viewYear: 2026
	property int viewMonth: 0
	property string svMode: "month"        // "month" | "year"
	property var svResult: null
	property bool svLoading: false
	property int svToken: 0
	property bool svInit: false
	property int fontBody: isNxt ? 18 : 14
	property int fontBig: isNxt ? 26 : 20

	onShown: {
		addCustomTopRightButton("Jaarverbruik invullen");
		if (!svInit) {
			var dm = Logic.defaultMonth(new Date());
			viewYear = dm.year;
			viewMonth = dm.month;
			svInit = true;
		}
		svReload();
	}

	onCustomButtonClicked: stage.openFullscreen(app.settingsScreenUrl)

	// Instellingen zijn geladen of opgeslagen: overzicht opnieuw berekenen
	Connections {
		target: app
		onUserSettingsChanged: {
			if (svScreen.showing) svScreen.svReload();
		}
	}

	function svReload() {
		if (!app) return;
		var my = ++svToken;
		svLoading = true;
		svResult = null;
		var cb = function (r) {
			if (my !== svToken) return;   // verouderd antwoord negeren
			svResult = r;
			svLoading = false;
		};
		if (svMode === "month") app.computeMonth(viewYear, viewMonth, cb);
		else app.computeYear(viewYear, cb);
	}

	function svCanNext() {
		var dm = Logic.defaultMonth(new Date());
		if (svMode === "month") return (viewYear * 12 + viewMonth) < (dm.year * 12 + dm.month);
		return viewYear < dm.year;
	}

	function svStep(delta) {
		if (svMode === "month") {
			var idx = viewYear * 12 + viewMonth + delta;
			viewYear = Math.floor(idx / 12);
			viewMonth = idx - viewYear * 12;
		} else {
			viewYear += delta;
		}
		svReload();
	}

	ControlGroup {
		id: modeGroup
		exclusive: true
		onCurrentControlIdChanged: {
			var newMode = currentControlId === 1 ? "year" : "month";
			if (newMode !== svMode) {
				svMode = newMode;
				svReload();
			}
		}
	}

	Flow {
		id: tabs
		anchors { left: parent.left; leftMargin: 20; top: parent.top; topMargin: 16 }
		spacing: 4

		TopTabButton {
			text: "Maand"
			controlGroupId: 0
			controlGroup: modeGroup
			selected: true
		}
		TopTabButton {
			text: "Jaar"
			controlGroupId: 1
			controlGroup: modeGroup
		}
	}

	Row {
		id: nav
		anchors { right: parent.right; rightMargin: 20; verticalCenter: tabs.verticalCenter }
		spacing: 12

		StandardButton {
			text: "<"
			onClicked: svStep(-1)
		}
		Text {
			anchors.verticalCenter: parent.verticalCenter
			width: isNxt ? 220 : 170
			horizontalAlignment: Text.AlignHCenter
			font { family: qfont.semiBold.name; pixelSize: fontBody }
			color: "black"
			text: svMode === "month" ? Logic.MONTHS[viewMonth] + " " + viewYear : "" + viewYear
		}
		StandardButton {
			text: ">"
			opacity: svCanNext() ? 1 : 0.3
			enabled: svCanNext()
			onClicked: svStep(1)
		}
	}

	// Samenvatting of melding
	Text {
		id: summary
		anchors {
			left: parent.left; leftMargin: 20
			right: parent.right; rightMargin: 20
			top: tabs.bottom; topMargin: 18
		}
		wrapMode: Text.WordWrap
		font { family: qfont.semiBold.name; pixelSize: fontBig }
		color: {
			if (!svResult || svResult.status !== "ok" || !svResult.total) return "black";
			return svResult.total.good ? "#2e7d32" : "#c62828";
		}
		text: {
			if (svLoading || !svResult) return "Gegevens ophalen...";
			if (svResult.status === "noconfig") return "Vul eerst uw jaarverbruik in";
			if (svResult.status === "error") return "Gegevens niet beschikbaar";
			if (svResult.status === "nodata") return "Nog geen volledige dag gemeten";
			if (!svResult.total) return "";
			var pre = svResult.partial ? "Tot nu toe " : (svMode === "month" ? "In " + Logic.MONTHS[viewMonth] + " " : "In " + viewYear + " ");
			return pre + (svResult.total.kind === "cost" ? svResult.total.text : svResult.total.short.toLowerCase() + " dan geschat");
		}
	}

	Text {
		id: hint
		anchors {
			left: parent.left; leftMargin: 20
			right: parent.right; rightMargin: 20
			top: summary.bottom; topMargin: 6
		}
		wrapMode: Text.WordWrap
		font { family: qfont.regular.name; pixelSize: fontBody }
		color: "#444444"
		visible: text !== ""
		text: {
			if (!svResult || svLoading) return "";
			if (svResult.status === "noconfig") return "Tik rechtsboven op \"Jaarverbruik invullen\" en vul uw verbruik per jaar in (staat op uw jaarnota).";
			if (svResult.message) return svResult.message;
			if (svResult.total && svResult.total.kind === "usage") return svResult.total.text + " (rechtsboven bij Jaarverbruik invullen).";
			return "";
		}
	}

	Column {
		id: cardColumn
		anchors {
			left: parent.left; leftMargin: 20
			right: parent.right; rightMargin: 20
			top: hint.visible ? hint.bottom : summary.bottom
			topMargin: 14
		}
		spacing: 12

		Repeater {
			model: (svResult && svResult.cards) ? svResult.cards : []

			Rectangle {
				width: cardColumn.width
				height: isNxt ? 150 : 120
				radius: 6
				color: "#eef0f2"

				Image {
					id: icon
					anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
					width: isNxt ? 48 : 38
					height: width
					sourceSize.width: width
					sourceSize.height: height
					fillMode: Image.PreserveAspectFit
					source: modelData.hasEstimate
						? "qrc://apps/statusUsage/drawables/" + modelData.kind + "_" + (modelData.good ? "good" : "bad") + ".svg"
						: "qrc://apps/statusUsage/drawables/" + modelData.kind + "_off.svg"
				}

				Text {
					id: cardTitle
					anchors { left: icon.right; leftMargin: 14; top: parent.top; topMargin: 10 }
					font { family: qfont.bold.name; pixelSize: fontBody }
					color: "black"
					text: modelData.title
				}

				Text {
					anchors { left: cardTitle.right; leftMargin: 12; baseline: cardTitle.baseline }
					font { family: qfont.semiBold.name; pixelSize: fontBody }
					color: !modelData.hasEstimate ? "#666666" : (modelData.good ? "#2e7d32" : "#c62828")
					text: modelData.diffText
				}

				Rectangle {
					id: barBg
					anchors {
						left: icon.right; leftMargin: 14
						right: parent.right; rightMargin: 16
						top: cardTitle.bottom; topMargin: 10
					}
					height: isNxt ? 18 : 14
					radius: height / 2
					color: "#d5d9dd"

					Rectangle {
						anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
						width: Math.min(1, modelData.ratio) * parent.width
						radius: parent.radius
						color: modelData.ratio > 1 ? "#c62828" : "#2e7d32"
					}
				}

				Column {
					anchors {
						left: icon.right; leftMargin: 14
						right: parent.right; rightMargin: 16
						top: barBg.bottom; topMargin: 8
					}
					spacing: 2
					Text {
						width: parent.width
						elide: Text.ElideRight
						font { family: qfont.regular.name; pixelSize: fontBody }
						color: "black"
						text: "Verbruikt: " + modelData.realText
					}
					Text {
						width: parent.width
						elide: Text.ElideRight
						font { family: qfont.regular.name; pixelSize: fontBody }
						color: "black"
						text: (svResult.partial ? "Geschat tot nu: " : "Geschat: ") + modelData.targetText
					}
					Text {
						width: parent.width
						elide: Text.ElideRight
						visible: svResult.partial
						font { family: qfont.regular.name; pixelSize: fontBody - 2 }
						color: "#555555"
						text: (svMode === "month" ? "Hele maand geschat: " : "Heel jaar geschat: ") + modelData.fullText
					}
				}
			}
		}
	}

	Text {
		anchors {
			left: parent.left; leftMargin: 20
			right: parent.right; rightMargin: 20
			bottom: parent.bottom; bottomMargin: 8
		}
		wrapMode: Text.WordWrap
		font { family: qfont.regular.name; pixelSize: fontBody - 3 }
		color: "#777777"
		text: "Geschat op basis van uw eigen jaarverbruik en een standaard seizoensverdeling. Indicatief; kan afwijken van uw jaarnota."
	}
}
