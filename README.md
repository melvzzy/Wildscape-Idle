# Wildscape Idle

Kleiner spielbarer 3D-Sandbox-RPG-Prototyp mit Godot **4.6.3 Standard / GDScript**
und Compatibility-Renderer. Keine Plugins oder externen Assets.

## Start und Steuerung

`project.godot` in Godot 4.6.3 importieren und **F5** drücken.

| Taste | Aktion |
| --- | --- |
| WASD | Bewegung relativ zur Kamera |
| Maus / Mausrad | Third-Person-Kamera drehen / zoomen |
| E | Nahe Ressource sammeln, Werkbank öffnen oder Meiler schalten |
| Tab | Lagerbuch mit Inventar, Skills, Rezepten und Speicherknöpfen |
| Esc | Maus freigeben / wieder einfangen |
| F6 / F9 | Speichern / Laden im laufenden Spiel |

Das Lagerbuch ist scrollbar. Beim Öffnen bleibt der Charakter stehen; die
Produktion läuft weiter. Sammelpunkte wachsen nach zwölf Sekunden nach.
Beim Sammeln in Reichweite bleiben; ein Weggehen bricht ohne Ertrag ab.
Der nächste erreichbare Sammelpunkt wird automatisch gewählt, ohne genaues Zielen.

## Spielschleife

1. Bäume und graue Felsen mit E sammeln; Mengen und Skill-XP im Lagerbuch ansehen.
2. An der Werkbank eine Steinaxt (3 Holz, 2 Stein) für doppelten Holzertrag oder
   eine Spitzhacke (4 Holz, 3 Stein) für die orangefarbenen Kupferadern herstellen.
3. Mit Spitzhacke und Kupfer den Meiler an der Werkbank freischalten
   (5 Holz, 5 Stein, 2 Kupfererz); am beschrifteten Meiler mit E einschalten.
4. Der Meiler wandelt alle 5 Sekunden 2 Holz in 1 Holzkohle um. Er wartet bei
   fehlendem Holz oder vollem Ausgabebestand und speichert keine Wartezeit auf.
5. Die Kupferaxt benötigt Steinaxt, 3 Holz, 4 Kupfererz und 2 Holzkohle und erhöht
   den Holzertrag auf drei. Werkzeuge wirken automatisch und verbrauchen sich nicht.

Holzfällen und Bergbau steigen alle 50 XP um ein Level. Jedes zusätzliche Level
beschleunigt das Sammeln um 5 Prozentpunkte, begrenzt auf zehn Verbesserungen.

## Speichern

Versioniertes JSON unter `user://save_v1.json` speichert Inventar, Werkzeuge,
Freischaltungen, Skill-XP und Meilerzustand samt Teilfortschritt. Automatisches
Laden beim Start; Speichern per F6, UI und beim regulären Schließen des Fensters.
Ein Schreibfehler beim Schließen hält das Fenster offen und zeigt den Fehler an.
Es gibt kein periodisches Autosave und keine Speicherung bei Prozessabbruch.
Geschrieben wird zuerst in eine temporäre Datei und danach per Umbenennen ersetzt.
Ungültige Daten ersetzen den aktuellen Spielzustand nicht.

Spielerposition und Ressourcencooldowns werden bewusst nicht gespeichert: Jede
Sitzung startet im Lager mit erneuerten Sammelpunkten. Keine Offline-Produktion;
es wird keine Zeit zwischen Programmstarts angerechnet.

## Aufbau

- `scenes/main/`: verbindet Welt, Spieler, Interaktionen und UI.
- `scenes/player/`: CharacterBody3D, Bewegung und SpringArm-Kamera.
- `scenes/world/`, `scenes/gathering/`: feste Testwelt und wiederverwendbare Sammelpunkte.
- `scenes/ui/`: Lagerbuch, Hinweise und Sammelfortschritt.
- `data/`: native Resources für Items, Rezepte, Gathering und Produktion;
  IDs bleiben stabil. Verfügbare Definitionen sind explizit in `GameState` registriert.
- `game/`: gemeinsamer Spielzustand mit atomaren Transaktionen und validiertem Save/Load.
- `tests/run_tests.gd`: Tests ohne externe Testabhängigkeit und ohne Schreiben in den echten Spielstand.

Keine Autoloads. Spiellogik liegt im `GameState`; die Hauptszene prüft zusätzlich
Reichweite, Sichtlinie und Interaktionsablauf. Zeitintervalle nutzen monotone
Millisekunden; die Produktion kann unabhängig von der Oberfläche getestet werden.

## Prüfungen

Aus dem Repository-Verzeichnis, mit Godot 4.6.3 im PATH:

```sh
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --quit-after 120
```

Die Tests decken Inventargrenzen, Crafting-Transaktionen, Werkzeuganforderungen,
Skill-XP, defekte Spielstände, Save-/Load-Roundtrip, Produktionsgrenzen und
zeitliche Aufteilung sowie Bewegung und Gathering in der echten Hauptszene ab.
Ein grafischer Testlauf ohne `--headless` prüft zusätzlich das Rendering und legt
zwei Vorschaubilder unter `user://wildscape_*_preview.png` ab.

Phasen A–F sind implementiert, einschließlich aktiver Produktion. Nicht enthalten
sind Offline-Erträge, Kampf, NPCs, Survival, freies Bauen oder Multiplayer.
Die Welt und der Charakter bestehen aus einfachen Platzhalter-Primitives.
Manuell noch das Kameragefühl, die Kamerakollisionen und den vollständigen Ablauf
mit echten Tastatur-/Mauseingaben beurteilen. Nächster Schritt: Architektur und
Spielschleife gemeinsam prüfen, danach Bedienung und Balance verbessern.
