# HandyMe Web — milepæler for Codex

## Mål
Lag en enkel, mobilvennlig Progressive Web App (PWA) for HandyMe som fungerer i nettleser på Android, iPhone, Mac og Windows. Eksisterende SwiftUI/iOS-app og iCloud-data skal ikke endres. Første versjon er en separat prototype med egne testdata, uten betalt server.

## Sikkerhetsregler — les først
1. Undersøk eksisterende prosjekt før du endrer noe. Oppsummer relevante modeller, beregningsregler og brukerflyter.
2. Ikke slett eller refaktorer SwiftUI-kode, heller ikke eldre hovedentreprise-/entreprenørkode. Ikke endre iOS-prosjektfil, iCloud/CloudKit, eksisterende data eller backupformat.
3. Lag webappen i et separat søskenprosjekt, for eksempel `HandyMe-Web`, utenfor iOS-prosjektmappen. Hvis du ikke har tilgang til riktig overordnet mappe, stopp og foreslå trygg plassering.
4. Arbeid i små, kontrollerbare steg. Vis endrede filer og testresultater etter hver milepæl. Ikke push eller deploy uten uttrykkelig beskjed.
5. Ikke importer ekte kundeopplysninger eller andre persondata. Bruk fiktive testdata.

## Teknologivalg
- React + TypeScript + Vite.
- Responsivt grensesnitt med norsk bokmål som standardspråk.
- PWA med manifest, ikoner og service worker; offline-funksjon må testes.
- Lokal datalagring i IndexedDB via et tydelig repository-lag (ikke localStorage som hoveddatabase).
- Stabile UUID-er, schemaVersion og opprettet-/endret-tidspunkt på alle sentrale dataobjekter.
- Ingen backend eller automatisk synkronisering i første versjon.
- JSON eksport/import med validering og sikkerhetskopi før import. Ingen skjult overskriving av eksisterende data.

## M0 — Kartlegg iOS-appen (ingen kodeendringer)
- Finn modellene for kunder, varer, prosjekter, arbeid, timer, reise, tilbud og priser.
- Identifiser reglene for mva., avrunding, priser eks. mva., timer og totalsummer.
- Dokumenter hva som er enkelt oppdrag versus hovedentreprise.
- Lag `IOS_FEATURE_MAP.md` og `CALCULATION_RULES.md` med henvisninger til relevante Swift-filer.
- Marker uklarheter; ikke gjett beregningsregler.
- Stopp og be om godkjenning av kartleggingen før M1.

## M1 — Opprett webprosjekt
- Lag separat Vite/React/TypeScript-prosjekt.
- Enkel navigasjon: Oversikt, Kunder, Varer, Prosjekter, Innstillinger.
- Mobilvennlig og skrivebordsvennlig layout, store trykkflater, lesbare skjemaer.
- Legg inn grunnleggende PWA-oppsett og lokal kjøreveiledning i `README.md`.
- Kjør bygg og eventuelle tester.

## M2 — Lokal datamodell og testdata
- Opprett typed modeller og IndexedDB repository-lag.
- Støtt opprett/rediger/slett for kunder og varer.
- Bruk fiktive kunder og varer, inkludert enhetspriser og måleenheter.
- JSON eksport/import med versjonskontroll, validering, forhåndsvisning og bekreftelse.
- Dokumenter hvordan man nullstiller bare webappens testdata.

## M3 — Enkle prosjekter
- Prosjekt med kunde, beskrivelse, status, datoer og linjer for materialer/arbeid.
- Registrer timer, timepris, reise og varer etter dokumenterte regler fra iOS.
- Lag tilbudsvisning og utskriftsvennlig visning/PDF via nettleserens utskrift.
- Hold hovedentreprise, underleverandører og arbeidspakker utenfor første versjon.

## M4 — Sammenligning med iOS
- Opprett et felles, fiktivt testscenario som kan legges inn manuelt i begge apper.
- Kontroller linjesummer, arbeidstimer, reisekostnad, rabatt hvis relevant, mva. og totalsum.
- Lag `PARITY_TESTS.md` med inndata, forventede utdata og avvik.
- Implementer automatiske enhetstester for beregningsreglene i webappen.
- Ikke juster webberegninger for å skjule avvik; undersøk årsaken.

## M5 — PWA og kvalitet
- Test installasjon på Android og åpning i moderne nettlesere.
- Test offline etter første innlasting og avklar hvilke funksjoner som virker uten nett.
- Test eksport, import, oppdatering av webapp og håndtering av lagringsfeil.
- Sjekk tilgjengelighet, mobiloppsett, sikkerhet og at ingen ekte persondata ligger i repoet.
- Dokumenter begrensninger ved lokal lagring: data kan forsvinne ved sletting av nettstedsdata, bytte av enhet eller nettleser.

## M6 — Senere, ikke implementer nå
- Vurder felles backend og autentisering for iOS/web.
- Vurder selektiv synkronisering av kunder, varer og priser.
- Planlegg migrering fra iCloud uten tap av eksisterende data.
- Planlegg konfliktløsning, tilgangsstyring, personvern og sikkerhetskopiering.
- Vurder avanserte hovedentreprisefunksjoner først etter at enkel webapp er verifisert.

## Første kommando til Codex
Les `WEB_MILESTONES.md`. Utfør kun M0 nå. Ikke endre eksisterende iOS-kode eller opprett webprosjekt før jeg har godkjent kartleggingen. Oppsummer funn, risiko og foreslått mappestruktur på norsk.
