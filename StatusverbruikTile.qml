import QtQuick 2.1
import qb.components 1.0

Tile {
	id: svTile
	property bool dimState: screenStateController.dimmedColors

	onClicked: stage.openFullscreen(app.configured ? app.screenUrl : app.settingsScreenUrl)

	Text {
		id: tileTitle
		anchors {
			baseline: parent.top
			baselineOffset: isNxt ? 30 : 24
			horizontalCenter: parent.horizontalCenter
		}
		font { family: qfont.regular.name; pixelSize: qfont.tileTitle }
		color: dimState ? "white" : "black"
		text: "Status verbruik"
	}

	Text {
		id: line1
		width: parent.width - 16
		anchors {
			top: tileTitle.bottom
			topMargin: isNxt ? 18 : 12
			horizontalCenter: parent.horizontalCenter
		}
		horizontalAlignment: Text.AlignHCenter
		wrapMode: Text.WordWrap
		font { family: qfont.bold.name; pixelSize: isNxt ? 28 : 22 }
		color: dimState ? "white" : (app.tileStatus !== "ok" ? "black" : (app.tileGood ? "#2e7d32" : "#c62828"))
		text: app.tileLine1
	}

	Text {
		width: parent.width - 16
		anchors {
			top: line1.bottom
			topMargin: 4
			horizontalCenter: parent.horizontalCenter
		}
		horizontalAlignment: Text.AlignHCenter
		wrapMode: Text.WordWrap
		font { family: qfont.regular.name; pixelSize: isNxt ? 18 : 14 }
		color: dimState ? "white" : "black"
		text: app.tileLine2
	}
}
