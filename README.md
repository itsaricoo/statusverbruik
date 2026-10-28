Status Verbruik voor rooted Toons

Een QML-app voor rooted Toons die je werkelijke stroom- en gasverbruik vergelijkt met een schatting op basis van je eigen jaarverbruik. Het is een vervanger voor de stock-app Status Verbruik (statusUsage), die zonder Quby/Eneco-cloud geen schatting kan tonen.

Status: experimenteel. De app is ontwikkeld zonder toegang tot een echte Toon en wordt nu voor het eerst op een Toon uitgeprobeerd. Zie Bekende beperkingen.

Wat doet de app?
Overzicht per maand en per jaar met een balk per energiesoort: verbruikt versus geschat, en het verschil in euro's (of in kWh/m³ als je geen tarieven invult).
Invulscherm voor je eigen jaarverbruik: stroom (normaal en laag tarief), gas, tarieven, en een schakelaar voor seizoensverdeling.
Tile op het startscherm met het verschil voor de huidige (of, op de 1e van de maand, de vorige) maand.
Werkt volledig lokaal: het verbruik komt uit de P1-gegevens van de Toon zelf. Er worden geen externe diensten aangeroepen.
Raakt geen systeembestanden aan (happ_pwrusage, config_happ_pwrusage.xml e.d. blijven ongemoeid).

Vereisten

Een rooted Toon 2 met de Toon Software Collective-omgeving (TSC) waarop community-apps draaien.
Firmware met de module qb.energyinsights (de lokale REST-aanroep voor verbruiksgegevens, ook gebruikt door de Graph-app).
De layout houdt rekening met Toon 1 en Toon 2 (isNxt), maar is alleen voor Toon 2 bedoeld en niet op Toon 1 getest.

Installeren

Kopieer de map statusverbruik naar de Toon als /qmf/qml/apps/statusverbruik. De mapnaam moet precies zo, in kleine letters heten: de Toon laadt de app onder die naam en zoekt dan StatusverbruikApp.qml. Linux is hoofdlettergevoelig.
Schakel de app in zoals je dat bij andere community-apps doet.
Verwijder bij een update eventuele oude .qmlc-bestanden in de map en herstart de GUI.
Voeg de tile "Status verbruik" toe via de tile-keuze.

Gebruik
Tik op de tile (zolang er niets is ingevuld staat er Jaarverbruik invullen) of ga naar het hoofdscherm en tik rechtsboven op Jaarverbruik invullen.
Vul je jaarverbruik en tarieven in. Je vindt ze op je jaarnota.
Veld	Eenheid	Opmerking
Stroom (normaal)	kWh/jaar	Bij enkel tarief: je totale jaarverbruik
Stroom laag	kWh/jaar	Alleen bij Dubbel tarief
Tarief stroom (normaal en laag)	euro/kWh	Inclusief btw, bijvoorbeeld 0,32
Gas	m³/jaar	
Tarief gas	euro/m³	Inclusief btw, bijvoorbeeld 1,40
Typ 0 om een veld leeg te maken.
Een tarief boven €5 wordt geweigerd, zodat 32 niet als €32 per kWh wordt opgeslagen.
Schakelaars: Stroom meenemen, Dubbel tarief, Gas meenemen en Seizoensverdeling.
Heb je een dubbele meter? Zet dan Dubbel tarief aan. Dan worden normaal en laag apart opgehaald en opgeteld.
Tik op Opslaan. Het overzicht wordt direct opnieuw berekend.

In het overzicht wisselt het tabblad Maand / Jaar, en met < en > blader je door de perioden.

Hoe wordt de schatting berekend?

Geschat verbruik van een maand = jaarverbruik x aandeel van die maand.
Seizoensverdeling aan: een vaste verdeling per maand. Gas verbruikt in de winter veel meer dan in de zomer, stroom varieert licht. Zie PROFILES in StatusverbruikLogic.js.
Seizoensverdeling uit: elke dag evenveel (dagen in de maand gedeeld door dagen in het jaar).
Tot nu toe (lopende maand of jaar) = schatting x aandeel van de volledig afgelopen dagen. De huidige dag telt dus nog niet mee. Op de 1e van de maand toont de app de vorige maand.
Verschil in euro's = geschatte kosten min werkelijke kosten (verbruik x je eigen tarief). Positief betekent minder verbruikt dan geschat.
Het verbruik zelf komt via EnergyInsights.Functions.requestData (stroom in Wh, gas in liter), opgehaald als som van dagwaarden (maandoverzicht) of, voor afgeronde maanden in het jaaroverzicht, als maandwaarden plus de dagwaarden van de lopende maand.

De seizoensverdeling is een eigen benadering en niet de verdeling van Quby (die is niet bekend). De uitkomst is indicatief en is geen jaarnota: vaste kosten, teruglevering en de verdeling van je leverancier zijn niet meegenomen. Zonnepanelen worden niet apart behandeld.

Instellingen en bestanden

Bestand	Doel
StatusverbruikApp.qml	App: registratie, laden/opslaan, data ophalen, tile-status
StatusverbruikScreen.qml	Hoofdscherm (maand/jaar)
StatusverbruikSettingsScreen.qml	Invulscherm voor jaarverbruik en tarieven
StatusverbruikTile.qml	Tile
StatusverbruikLogic.js	Rekenlogica en opmaak (geen QML-afhankelijkheden, los te testen)
version.txt, Changelog.txt	Versie en wijzigingen

Je instellingen staan in /mnt/data/tsc/statusverbruik.userSettings.json. Na het opslaan wordt het bestand teruggelezen ter controle; lukt dat niet, dan zie je een rode melding op het invulscherm. Het icoon van de tile komt uit de stock-app (qrc://apps/statusUsage/drawables/...) en wordt niet meegeleverd.

Bekende beperkingen

Antwoordformaat van de REST-service (belangrijkste aanname). De app gaat ervan uit dat de service voor interval=days|months precies één waarde per interval in [from, to) teruggeeft. Dat volgt uit de code van de Graph-app, maar is niet op een echte Toon bevestigd. Klopt het niet, dan toont de app "Kon het verbruik niet ophalen".
Enkel tarief. Bij een enkele meter wordt zonder tariefparameter opgevraagd. Of dat altijd het totaal geeft, is niet bevestigd.
Tarieven en jaarverbruik worden niet automatisch gelezen (bijvoorbeeld uit config_happ_pwrusage.xml); je vult ze zelf in.
Niet gegarandeerd op alle firmwareversies, omdat de app steunt op qb.energyinsights.

Problemen melden

Open een issue en plak de relevante regels uit de QML-log van de GUI (de regels die met qml: beginnen), plus je firmwareversie. Let vooral op regels met:

Statusverbruik: onbruikbaar antwoord ...: de app logt hier het ruwe antwoord van de REST-service. Dat is precies wat nodig is om de eerste aanname te controleren.
... is not a type of ... is not installed: een QML-component of module ontbreekt op jouw firmware.
Error loading file ...: meestal een afwijkende mapnaam (zie Installeren).
Ontwikkelen en testen

De rekenlogica in StatusverbruikLogic.js is bewust zonder QML geschreven en draait onder Node.js. Voor qmllint zijn de Toon-specifieke modules (qb.components, BasicUIControls) buiten de Toon niet beschikbaar; alleen de syntaxis valt dus daar te controleren. Het opbouwpatroon (bestandsindeling, registratie, opslag via XMLHttpRequest naar /mnt/data/tsc/<app>.userSettings.json) volgt de TSC-apps zoals spotenergy.
