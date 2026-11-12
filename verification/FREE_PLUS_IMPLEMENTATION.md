# Gratis og Pluss – første implementering, 12. november 2026

Terje har valgt engangskjøp: 399 kr ordinært og 299 kr ved introduksjon.
StoreKit-kjøp og gjenoppretting er implementert; se PLUS_PURCHASES.md.
Produktet er nå opprettet i App Store Connect med 299 NOK; se PLUS_PURCHASES.md. Dette arbeidet
er ikke lastet opp til TestFlight; den publiserte build 10 er uendret.

## Tilgang

- Gratis: ett redigerbart aktivt oppdrag. Planlagt og pågående regnes som
  aktive, også øvingsoppdrag. Fullført og arkivert opptar ikke plassen.
- Gratis: kunder, registreringer, manuell material-/prisregistrering, bilder,
  oppdrags-PDF med og uten priser, deling, utskrift og full backup/restore.
- Pluss: flere aktive oppdrag, ny faktura/kreditnota og fakturautkast,
  regnskapseksport, samlerapporter og gjenbruk/redigering av produktkatalog.
- Begge: les og eksporter gamle oppdrag, fakturaer og kreditnotaer. Lagrede
  fakturautkast beholdes og kan forhåndsvises gratis.
- Et fullført gratisoppdrag gjenåpnes eksplisitt før redigering. Gjenåpning
  tillates bare dersom ingen andre oppdrag er aktive.
- Flere aktive fra eldre versjon, backup eller nedgradering slettes eller
  fullføres aldri automatisk. Brukeren velger ett å redigere. Valget beholdes
  til oppdraget fullføres/arkiveres; de andre har fortsatt lesetilgang og PDF.

## Data og teknikk

SwiftData-modellene og backupformatet er uendret. Tilgangspolicyen gjør ingen
skriving til oppdrag. Valgt gratisoppdrag lagres separat i lokale innstillinger;
Pluss-tilgang eksporteres aldri i en backup. Tilgangen leveres av AccessStore,
mens JobAccessPolicy beregner oppdragsbegrensningene.

Utviklingsbygg har en midlertidig nivåvelger under Innstillinger → Se Gratis
og Pluss → Utviklingstest. Pluss-testen gjelder bare inneværende appøkt.
Release-bygget har ingen slik velger og bruker verifiserte Apple-kjøp.
Kjøp og gjenoppretting er nå implementert og lokalt testet; produktet må
konfigureres i App Store Connect og Sandbox-testes før betalingslansering.
Ingen testbryter brukes som ekte kjøpsbevis.

Kildekode og tidligere tester er sikret før endringen:
`~/Documents/JobbBevis-sikkerhetskopier/JobbBevis-for-Pluss-2026-11-12.tar.gz`.
Simulatorenes eksisterende data er også kopiert med SQLite backup-API før
installasjon, i samme mappe under `iPhone17-for-Pluss-2026-11-12` og
`iPadPro13-for-Pluss-2026-11-12`. Ingen avinstallasjon eller simulatorreset.

## Kontroll utført

- Debug-bygg på iPhone 17: bestått.
- Release-bygg for iOS-enhet, uten signering: bestått.
- Samlede funksjonstester og opprinnelig databaseskjema-migrasjon: bestått.
- Ny AccessPolicyChecks: null/ett/flere aktive, eksplisitt valg, gratis/Pluss,
  nedgradering, fullføring/gjenåpning, bevart fakturakopi og backup/restore med
  egne fiktive oppdrag, timer, materialer og bildefil: bestått.
- PDF-regresjonstestene for flere sider, priser og seks bilder: bestått.
- iPhone via Device Hub: opprettet første fiktive gratisoppdrag; nytt oppdrag
  ledet til Pluss; testvelger til Pluss tillot oppdrag nummer to; gratis igjen
  beholdt begge og viste nummer to skrivebeskyttet. PDF fra skrivebeskyttet
  oppdrag generert. Norske tekster og nivåvelger kontrollert.
- Oppfølgende iPad Pro 13-kontroll: bestått for oppretting av første
  gratisoppdrag og blokkering av nummer to, lagring av én testtime, fullføring
  med bevart time og skrivebeskyttelse, PDF fra fullført oppdrag og gjenåpning
  når plassen er ledig. Pluss tillot et andre oppdrag. Gratis igjen beholdt
  begge og låste det andre. Gjenåpning av et fullført ekstraoppdrag mens første
  fortsatt var aktivt, ble korrekt blokkert.
- Testen avdekket en navigasjonsfeil: aktivt gratisoppdrag fikk skrivebeskyttet
  arbeidslogg fordi miljøverdien ikke fulgte NavigationStack-destinasjonen.
  Rettet med jobEditingAccess(for:) som beregner tilgang inne i destinasjonen.
  Brukes for bilder, arbeidslogg, materialer og innkjøpsliste, samt bildedetalj
  og innkjøpsliste fra tilbudsvisningen. Gratis arbeidslogg kunne deretter
  åpnes og lagres på iPad; fullført oppdrag var fortsatt korrekt låst.
- Felles retting kontrollert på iPhone 17: eksisterende testoppdrag beholdt,
  aktiv gratisarbeidslogg åpnet et redigerbart norsk registreringsskjema.
- Begge simulatorer er beholdt. To tydelig merkede fiktive oppdrag finnes på
  hver; på iPad er JB-0001 aktivt med én testtime og JB-0002 fullført.

Logger:
`/private/tmp/JobbBevis-plus-build.log`
`/private/tmp/JobbBevis-plus-release.log`
`/private/tmp/JobbBevis-plus-checks.log`

## Neste kontroll før ny TestFlight

1. Konfigurer engangskjøpet i App Store Connect og kjør Sandbox-testene
   beskrevet i PLUS_PURCHASES.md. Lokal StoreKit-kontroll er bestått.
2. Utvidet kontroll av alle Pluss-innganger og eksplisitt valg ved import av
   flere aktive oppdrag uten et tidligere gratisvalg. Grunnflyten på iPad er kontrollert.
3. Kontroller åpent skjema ved nivåbytte, fullføring og gjenåpning på begge
   skjermstørrelser, samt faktisk deling/utskrift på fysiske enheter.
4. Avtal om eksisterende betatestere skal få en overgangsperiode. Ingen
   permanente gratisrettigheter eller unntak er tildelt automatisk.
