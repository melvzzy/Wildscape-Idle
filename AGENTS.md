# Entwicklungsregeln

- Godot 4 und GDScript verwenden; keine Plugins oder externen Abhängigkeiten ohne konkreten Bedarf.
- Änderungen klein, verständlich und auf den Auftrag begrenzt halten. Keine Spielsysteme auf Vorrat implementieren.
- Godot-Konventionen nutzen: PascalCase für Nodes und Klassen, snake_case für Dateien, Variablen und Funktionen; Tabs für GDScript-Einrückung.
- GDScript möglichst statisch typisieren; kurze Funktionen mit klarer Verantwortung schreiben. Kommentare erklären Gründe statt offensichtlichen Code.
- Einfache Szenenkomposition bevorzugen. Keine spekulativen Frameworks, globalen Manager oder Autoloads; Signale nur bei sinnvollem Entkopplungsbedarf einsetzen.
- Zusammengehörige Szenen, Skripte und Ressourcen nach Funktion ablegen. Wiederverwendbare Teile erst bei konkretem Bedarf extrahieren; keine leeren Platzhalterordner anlegen.
- Szenen und Ressourcen deklarativ im Editorformat pflegen. Keine absoluten Dateipfade oder generierten Cache-/Build-Dateien versionieren. `.uid`-Dateien erhalten.
- Nach Änderungen passende Import- und Startprüfungen durchführen, bei visuellen Änderungen nach Möglichkeit auch das gerenderte Ergebnis ansehen. Fehler beheben und tatsächliche Tests sowie Grenzen knapp berichten.
