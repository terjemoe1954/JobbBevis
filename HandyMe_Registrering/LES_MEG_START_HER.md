# HandyMe – testpakke med separate registre

Dette er syntetiske data for HM-2026-001. Alle priser er illustrasjoner, ikke innhentede tilbud. Adresse og kunde er fiktive. Ikke send anbud/ordrebekreftelse som ekte avtaler.

## Filer
- HandyMe_Registrering.xlsx: ni separate faner med registrene.
- CSV-filer: én per register, semikolonseparert UTF-8 med BOM for norsk Excel.
- Anbud_HM-2026-001.md: tilbudsutkast.
- Ordrebekreftelse_HM-2026-001.md: ordreutkast, ikke akseptert.

## Registreringsrekkefølge
1. Opprett kunde fra Kunderegister.
2. Opprett prosjekt med KundeID K-001 fra Prosjekt.
3. Legg inn varer fra Vareregister (V-001 osv.).
4. Legg inn arbeidspakker og knytt dem til prosjektet.
5. Registrer planlagte timer fra Timebruk. Null registrerte timer – arbeidet er ikke påbegynt.
6. Legg inn reise som plan, ikke som gjennomført kjøring.
7. Lag handleliste fra Handleliste; ingen varer er bestilt.
8. Knytt før/etter-illustrasjonene fra den tidligere bildepakkens Bilder-mappe til Bilderegister. De er AI-bilder, ikke faktisk dokumentasjon.
9. Lag tilbudsutkast fra Anbud. Ikke marker som godkjent.
10. Test ordrebekreftelse etter en simulert godkjenning, uten å endre ekte data.
11. Kontroller kontrollpunkter og rapporter manglende funksjoner.

## Viktige avklaringer
- Arbeidspakkenes 1 385 000 kr er inkl. mva. 15 % reserve = 207 750 kr, total budsjettramme = 1 592 750 kr.
- Vareregister er *material-/utstyrspakker*, ikke faktiske SKU-er. Spesifikke produkter, antall og leverandører avklares senere.
- Timebruk viser 905 planlagte fagarbeidstimer. Ikke legg timepris x timer oppå arbeidspakkenes arbeidsbeløp; det vil dobbeltelle.
- Reise: 12 tur-retur, 190 km og 3 timer hver vei = 4 560 km og 72 kjøretimer, foreløpig estimat. Reise er ikke inkludert i prisrammen.
- Eksisterende bad/toalett og eventuelle søknadspliktige endringer er ikke inkludert.

## Codex-kommando
Les LES_MEG_START_HER.md og de separate CSV-filene. Kartlegg først eksisterende datamodeller og registreringsskjermer i HandyMe. Importer testkunden og prosjektet HM-2026-001 som DEMO uten å overskrive eller duplisere eksisterende data. Opprett vare-, arbeidspakke-, time-, reise- og handlelister med korrekte relasjoner. Vis tilbud og ordrebekreftelse som utkast, ikke som aksepterte dokumenter. Ikke registrer planlagte timer som utførte timer, eller planlagte reiser som gjennomførte. Oppgi hvilke felter eller funksjoner som mangler før større kodeendringer. Bygg og test appen.
