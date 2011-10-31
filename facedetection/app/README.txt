[Kompilieren]

Die Applikation kann in zwei unterschiedlichen Betriebsmodi kopmiliert werden:

- Normalmodus
- Testmodus

Im Normalmodus läuft die Applikation am Target, holt Bild für Bild von der Kamera,
führt die Gesichtsdetektion durch und gibt das Bild mit umrandeten Gesicht auf dem
Touchscreen aus. Zum Kompilieren der Applikation in diesem Modus einfach "make" 
auf der Konsole ausführen.

Im Testmodus verarbeitet die Applikation nur ein Bild, das über die
serielle Schnittstelle empfangen wird. Das Bild mit umrandeten Gesicht wird danach
wieder an den PC zurückgeschickt. Zur Performance-Evaluation wird in diesem Modus
die Ausführungsdauer der Gesichtserkennung gemessen. Zum Kompilieren in diesem
Modus "make TEST=1" auf der Konsole ausführen.


Erklärung der Output-Files:

- main.srec

Programmer-File zum Download auf das Target-System. Das macht man im Normalfall
einfach mit dem Testprogramm (siehe ../tester), das sich um den kompletten Download
kümmert. Man kann aber auch einfach eine serielle Konsole öffnen (z.B. gtkterm) und 
die Datei als raw-File runterladen. Die serielle Schnittstelle muss dann folgendermaßen
konfiguriert werden:
115200 Baud, 8 Datenbytes, Even Parity, 1 Stopbit

- main.txt

SCARTS Disassembly zum Analyse des erzeugten Maschinencodes.


[Debuggen]

Leider hat der Scarts-Debugger noch diverse Probleme. Daher empfehlen wir für diese Übung
den ganz normalen x86-gdb zum Debuggen zu verwenden. Um den Code für x86 zu kompilieren,
gibt es ein eigenes Makefile. Deses kann mit dem Befehl "make -f Makefile_debug" ausgeführt
werden. Dabei wird ein x86-Binary (Dateiname: main_x86) erzeugt, welches ganz normal am PC
ausgeführt bzw. debuggt werden kann. Zum Debuggen entweder gdb in der Konsole starten:

gdb ./main_debug

oder mit "ddd" als grafisches gdb Front-end:

ddd ./main_debug

Damit die Applikation auf dem PC lauffähig ist, gibt es im Source-Code einige Ifdefs
(siehe src/main.c) um die Zugriffe auf die Extension-Module des Scarts zu ersetzen. Will man
z.B. im Scarts das 7Seg-Display ansteuern, dann sollte das folgendermaßen gemacht werden:

#ifndef __SCARTS_32__
  dis7seg_displayUInt32(&dispHandle, 0, imageLen);  
#else
  // alternate output if executed on PC
  printf("ImageLen: %d\n", imageLen);
#endif

Achtung: Wechselt man beim Kompilieren zwischen Scarts- und PC-Modus, dann muss vorher
immer "make clean" ausgeführt werden, um die alten object-Files zu Löschen.


[Ausführen]

Die Funktionsweise des Algorithmuses kann am PC gestestet werden, in dem man die Applikation
folgendermaßen kompiliert: make -f Makefile_x86 TEST=1
Die erzeugte Programmdatei kann dann wie folgt ausgeführt werden:
./main_x86 image_in.tga image_out.tga

Als Testbilder können die Referenzbilder im Unterordner "testimages" verwendet werden.
Um eigene Bilder zu verwenden, müssen diese im tga-Format abgespeichert werden 
(umkomprimiert, Urspung oben links). 
