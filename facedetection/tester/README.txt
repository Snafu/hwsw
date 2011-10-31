Zum Kompilieren des Testers einfach in einer Konsole "make" ausführen.

Der Testen dient zum Downloaden der Applikation, die im Testmodus kompiliert
wurde, auf den Scarts. Nach der Übertragung des Programfiles, startet das
Programm am Scarts-Prozessor und wartet auf die Übermittlung eines Bildes.

Nach erfolgreicher Verabreitung der Bilderdatei, empfängt der Tester
die Ergebnisbild und speichert dieses als Datei ab.

Der Kommonadozeilenaufruf des Testers sieht folgendermaßen aus:
./tester <program.srec> <image_in.tga> <image_out.tga>
