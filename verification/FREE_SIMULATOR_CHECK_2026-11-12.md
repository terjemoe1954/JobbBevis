# Gratis – simulator kontrollert 12. november 2026

Testet i Debug-bygg av build 11-koden på iPhone 17 (iOS 27.2), med
utviklingsvelger satt til Gratis. Bare fiktive simulatoroppdrag er endret.

Bestått gjennom Device Hub:
- Ekstra aktivt oppdrag sperres og åpner Pluss-siden.
- Eldre aktive oppdrag beholdes; ett kan redigeres om gangen.
- Registrert én arbeidstime på JB-0001.
- PDF laget med kunde, dato, beskrivelse og én time total. Visuelt
  kontrollert uten vannmerke eller Pluss-sperre.
- Fullført JB-0001 og JB-0002; opprettet JB-0003 gratis etterpå.
- Eksportert backup til På min iPhone; appen bekreftet eksporten.
- Lest samme fil tilbake, kontrollert innhold og gjenopprettet i Gratis.
- Appen bekreftet gjenoppretting og viser fortsatt Gratis med JB-0003.
- SQLite etter restore: tre oppdrag, to fullførte, ett aktivt planlagt,
  arbeidsregistrering med 60 minutter bevart.

Filvelgeren var først hvit. Etter Hjem og retur til appen kunne eksport
og import fullføres gjennom UI. Fysisk iCloud-lagring og utskrift er ikke
kontrollert i denne testen.

Artefakter:
- /private/tmp/JobbBevis-free-ui-report.pdf
- /private/tmp/JobbBevis-free-ui-backup.json
- Sikring før test: /private/tmp/JobbBevis-before-free-ui-20261112

UDID: 1AC5CF22-4235-4E14-B4E8-244FC3B74F2C.
Simulatoren står igjen på Gratis med TEST Gratis kontroll (JB-0003).
Ingen produksjonskode endret. Fysiske enheter og kjøp er uendret.
