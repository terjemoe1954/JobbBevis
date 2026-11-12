# Pluss-kjøp – 12. november 2026

## Avtalt produkt og pris

- Ett varig engangskjøp (Non-Consumable), ikke abonnement.
- Produkt-ID: `com.terjemoe.JobbBevis.plus`.
- Ønsket norsk lanseringspris: 299 kr. Ordinær pris: 399 kr.
- Introduksjonsperioden er avtalt til de første 30 dagene etter lansering. Lanseringsdato er ikke satt. Ingen dato er funnet på
  eller datofestet økning satt i produksjon. Produktet er nå opprettet i App
  Store Connect med 299 NOK; 399 NOK planlegges når lanseringsdato er kjent.
- Samme produkt-ID brukes ved begge priser. Eksisterende kjøpere beholder
  tilgang etter prisendring. Appen viser Product.displayPrice fra Apple,
  uten hardkodet beløp, førpris eller udokumentert rabattpåstand.

## Implementasjon

ApplePlusStorefront henter kun det forventede non-consumable-produktet.
Kjøp låser bare opp Pluss etter verifisert Apple-transaksjon med riktig
produkt-ID, produkttype og uten tilbakekalling. Tilgang oppdateres før
transaksjonen fullføres. Ventende kjøp og brukeravbrudd gir ikke ny tilgang.

AccessStore starter en Transaction.updates-lytter før oppstartskontrollen.
Transaction.currentEntitlements sjekkes ved oppstart, ved retur til appen og
ved nye transaksjoner. Gjenopprett kjøp kaller AppStore.sync kun ved brukerens
trykk, og leser deretter verifiserte rettigheter. Tilgang lagres ikke som en
betalingsbryter i UserDefaults eller i backup. StoreKit leverer kjøpsbeviset.

Tilgangskoden endrer ingen oppdrag, bilder, fakturaer eller backupformat.
Tilbakekalling går tilbake til gratispolicyen, med tidligere valg av aktivt
oppdrag beholdt og de andre oppdragene fortsatt lesbare/eksporterbare.

Utviklingsvelgeren har nå tre valg: Apple-kjøp, Gratis og Pluss. Den er fortsatt
kun tilgjengelig i Debug og gjelder bare appøkten. Kjøp/gjenoppretting avslutter
manuell testoverstyring. Release inneholder ingen slik overstyring.

## Lokal testing uten belastning

`JobbBevisPlus.storekit` inneholder ett lokalt testprodukt til 299 NOK.
Det separate Xcode-skjemaet `JobbBevis StoreKit Local` velger filen ved Run.
Det vanlige JobbBevis-skjemaet og Archive velger ingen lokal testbutikk.
Kopien i CoreTests/Resources brukes bare av den isolerte SKTestSession-testen;
filene må holdes like. De er ikke produktkonfigurasjon i App Store Connect.

- PlusPurchaseChecks kontrollerer kjøp/avbrudd/ventende godkjenning, senere
  godkjenning, gjenoppretting med og uten kjøp, feil, uverifisert avvisning,
  tilbakekalling, duplikatkjøp og bevart gratisoppdragsvalg med kontrollerte
  adapter-svar. Inngår i verification/run_release_checks.py.
- PlusStoreKitTests kjører den faktiske Apple-adapteren med SKTestSession og
  lokale transaksjoner: kjøp, verifisert tilgang ved ny AccessStore,
  gjenoppretting og tilbakebetaling. Ingen ekte betaling.
- Apples lokale integrasjonstest bestod. Testen hoppes over i det vanlige
  skjemaet; bruk JobbBevis StoreKit Local for å aktivere testbutikken.

## Før Sandbox/TestFlight og release

1. Produkt, lokaliseringer, tilgjengelighet, pris og aktiv avtale er kontrollert
   i App Store Connect. Kontroller Sandbox på fysiske enheter.
2. Når lanseringsdato er satt, legg inn 399 NOK etter de første 30 dagene.
3. Kjør Sandbox/TestFlight på fysiske iPhone/iPad med kjøp, gjenoppretting på
   samme Apple-konto, avbrudd, ventende kjøp, offline oppstart og tilbakekalling.
4. Kontroller at alle lagrede data, PDF og backup beholdes ved tilgangsbytte.
5. Legg kjøpet ved riktig App Review-innsending. Ingen opplasting er gjort her.

Apple-referanser:
https://developer.apple.com/documentation/storekit/transaction/currententitlements
https://developer.apple.com/documentation/storekit/appstore/sync()
https://developer.apple.com/documentation/storekit/in-app-purchase

## Endelig kontroll

Apples lokale StoreKit-test bestod på iPhone 17: kjøp, ny oppstart,
gjenoppretting og refusjon. Kjør med skjemaet `JobbBevis StoreKit Local`;
det vanlige skjemaet kobler ikke til det lokale testproduktet.
Logg: `/private/tmp/JobbBevis-storekit-local.log`. Ingen ekte betaling.

Endelig Release-bygg bestod (CODE_SIGNING_ALLOWED=NO). Hele
run_release_checks.py bestod, inkludert kjøpspolicy, PDF og migrering fra
opprinnelig skjema. git diff --check var ren.

## App Store Connect og build 11

Produkt 6833772803 er opprettet med riktig SKU, Non-Consumable og Norge
som prisgrunnlag. 299 NOK er lagret, norsk og engelsk tekst er lagt inn,
tilgjengelighet og review-notat er lagret, og ekte review-skjermbilde er
lastet opp. Paid Apps Agreement er aktiv. Release-appen hentet 299,00 kr
fra Apple. Ordinær 399 NOK skal tre i kraft 30 dager etter lanseringsdato;
ingen ukjent dato er lagt inn. Build 11 er arkivert og eksportert, ikke
lastet opp. Se TESTFLIGHT_1.0.2_11.txt.

## TestFlight-distribusjon

Build 11 er lastet opp 12. november 2026, ferdigbehandlet og tilgjengelig
for Internal-gruppen. Sendt til ekstern betagodkjenning; External Beta viser
Approved. Testinstruksjoner og betareview-notat er lagret.
Build-ID: 8c9d4b8c-2370-4ff8-82ef-8f13947fe226.
TestFlight-kjøp bruker sandbox, uten belastning, og overføres ikke til
produksjon. Test kjøp på første enhet og gjenoppretting på den andre med
samme Apple-konto. Fysisk enhetstest er ikke utført av Codex.
