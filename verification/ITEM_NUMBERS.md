# Varenummer på jobbposter

Innkjøps- og materiallinjer har eget valgfritt varenummer. Listene, koblingsvelgeren og deloverføringsskjemaet viser nummer og navn. Kopiering fra vareregister tar med nummeret som en verdi på jobbposten, uten levende oppslag etter varenavn. Deloverføring kopierer kildelinjens nummer. Manuelle linjer kan ha eller mangle nummer; eksisterende linjer fylles ikke automatisk. Nummer kan rettes eksplisitt i skjemaet uten å endre vareregisterets identitet. Ved lagring som ny katalogvare overtar jobbposten den nye katalogvarens tildelte nummer.

Senere endringer i registerets varenummer eller navn påvirker ikke tidligere jobbposter. Ingen fakturasnapshot eller allerede utstedt dokument endres. Rapporter får egen gjennomgang i neste arbeidspunkt.

Sikkerhetskopier eksporterer og gjenoppretter de nye valgfrie feltene. Eldre sikkerhetskopier uten feltene kan fortsatt leses. Ingen økning av backupformatets versjon er nødvendig for disse valgfrie tilleggene.

Kontrollert: Xcode-bygg; isolert test av 2 + 8 kg med nummer, endring i vareregister uten endring av jobbpost, manuell linje uten nummer, backupinnhold og eldre backupformat. Gammel testdatabase oppgradert med bevart navn, pris, mengde og forbrukskobling; nye nummerfelter startet tomme og kunne lagres etter eksplisitt redigering. Brukerdata er ikke åpnet. Ikke installert eller sendt til TestFlight.
