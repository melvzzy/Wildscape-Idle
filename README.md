# Wildscape Idle

Technische Basis für ein späteres atmosphärisches 3D-Retro-Low-Poly-Sandbox-RPG.
Aktuell enthält das Projekt ausschließlich eine statische 3D-Startszene.

## Starten

Godot **4.3 oder neuer (4.x, Standard-Version mit GDScript)** verwenden.
`project.godot` im Godot-Projektmanager importieren und mit **F6** die geöffnete
Hauptszene oder mit **F5** das Projekt starten. Keine Plugins oder externen Assets nötig.
Der Compatibility-Renderer hält die Hardwareanforderungen gering.

## Struktur

- `project.godot`: Projekteinstellungen und Startszene.
- `scenes/main/main.tscn`: Boden mit Kollision (Oberkante bei Y = 0), Kamera,
  Sonnenlicht und Umgebung; Materialien und Geometrie sind lokal eingebettet.
- `AGENTS.md`: Regeln für weitere Entwicklung.

Ordner erst bei tatsächlichem Bedarf ergänzen. Zusammengehörige Szenen, Skripte
und Ressourcen nach Funktion gruppieren; gemeinsam genutzte Ressourcen erst bei
konkreter Wiederverwendung auslagern. Noch keine Steuerung oder Spielsysteme vorhanden.

## Technische Prüfung

Mit einem Godot-Executable im PATH aus dem Repository-Verzeichnis:

```sh
godot --headless --path . --editor --import
godot --headless --path . --quit-after 120
```

Die erste Prüfung importiert und lädt das Projekt, die zweite startet die
konfigurierte Hauptszene für 120 Frames. Für die visuelle Kontrolle zusätzlich
im Editor F5 drücken. `.godot/` und lokale Builds werden nicht versioniert;
Godot-UID-Dateien dagegen schon.
