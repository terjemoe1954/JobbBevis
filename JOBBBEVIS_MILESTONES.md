# JobbBevis – milepæler for generell prototype

Dato: 25. oktober 2026
Arbeidsnavn: JobbBevis
Kort beskrivelse: Dokumenter oppdrag, bilder, timer og materialer – lag en ryddig rapport til kunden.

Navnet er et arbeidsnavn. Tilgjengelighet i App Store, domener og eventuelle varemerker er ikke undersøkt. Appen dokumenterer registrert arbeid; navnet innebærer ingen sertifisering eller garanti for utførelse.

## 1. Instruks til Codex

Les hele filen og undersøk eksisterende prosjekt før du endrer noe. Følg eventuell AGENTS.md. Arbeid trinnvis fra første uferdige milepæl. Implementer en fungerende, enkel løsning fremfor bare å beskrive den. Bevar eksisterende brukerdata og fungerende kode.

Gjennomfør én milepæl om gangen. Bygg og kontroller relevante funksjoner, oppdater avkrysningene og skriv kort hva som er gjort, hva som er kontrollert og eventuelle begrensninger. Fortsett med neste milepæl når forrige fungerer, med mindre brukeren ber om noe annet. Ikke marker en enhetstest eller fysisk enhetstest som utført hvis den ikke er kjørt. Hvis byggmiljøet mangler, dokumenter nøyaktig hva brukeren må kontrollere i Xcode.

Start med milepæl 0 og 1. Ikke legg til betaling, server, innlogging, AI, fakturering eller fagspesifikke regelverk i prototypen.

## 2. Produktmål og avgrensning

En selvstendig håndverker skal kunne opprette et oppdrag, dokumentere arbeidet og dele en lesbar PDF uten internett. Første versjon er generell og skal kunne demonstreres for ulike håndverksfag. Ingen obligatorisk onboarding.

Hovedflyt: Kunde → oppdrag → bilder og arbeidslogg → materialer → forhåndsvis rapport → del eller skriv ut.

Første versjon gjelder én bruker og én lokal firmaprofil. iCloud-synk, samarbeid, signaturer, tilbud, prisberegninger, MVA, fakturaer, timetaker og fagmaler vurderes etter tilbakemeldinger. Timer og materialer er dokumentasjon og fakturagrunnlag, ikke en faktura. Ingen automatisk påstand om forskriftsmessig arbeid.

## 3. Teknisk utgangspunkt

- Swift og SwiftUI i brukerens installerte Xcode. Målplattform er iOS/iPadOS 27; kontroller faktisk SDK og tilgjengelige API-er i prosjektet før bruk. Ikke oppgrader eller endre brukerens Xcode-installasjon.
- Appen støtter iPhone og iPad med fleksibel navigasjon.
- SwiftData for strukturert lokal lagring, uten CloudKit i første versjon. Bruk en enkel repository/service-grense uten unødig arkitektur.
- Bilder og logo lagres som administrerte filer i appens Application Support. Databasen lagrer relative filreferanser. Ikke lagre absolutte sandbox-stier eller kun referanser til bildebiblioteket.
- Bruk plattformens PDF-, delings- og utskriftsfunksjoner. Ingen tredjepartsavhengigheter uten et konkret behov.
- String Catalog for norsk bokmål og engelsk. Systemvalg og eksplisitt språkvalg i appen. Datoer og tall formateres etter valgt språk/region.
- Utseende: system, lyst og mørkt. Lagre brukerens valg.
- Kildekode deles i Models, Views, Services, Config og Resources; mindre undermapper ved behov. Unngå tomme lag og store samlefiler.
- Erstatt ContentView med JobsView som oppdragsoversikt. AppRootView kan eie faner/navigasjon. Unngå dupliserte app-entrypoints.

## 4. Datamodell

Alle hovedobjekter skal ha stabil UUID og relevante opprettet/endret-tidspunkter.

| Modell | Viktige felt |
| --- | --- |
| CompanyProfile | Firmanavn, valgfritt organisasjonsnummer, telefon, e-post, adresse, logo |
| Customer | Navn, valgfri kontaktperson, telefon, e-post, adresse |
| Job | Oppdragsnummer, tittel, kunde, egen arbeidsadresse, beskrivelse, planlagt dato, status, ferdigdato |
| JobPhoto | Oppdrag, relativ bildefilsti, kategori før/underveis/etter, bildetekst, registrert dato, sorteringsrekkefølge |
| WorkEntry | Oppdrag, arbeidsdato, beskrivelse, varighet i hele minutter |
| MaterialEntry | Oppdrag, navn, mengde som Decimal, enhet, valgfri merknad |

Vis varighet som forståelige timer/minutter; ikke tolk 1,30 timer som 1 time 30 minutter. Mengder støtter lokale desimaltegn. Enheter starter med stk, m, m², m³, l, kg og pakke, samt fritekst. Ingen priser i første versjon.

Statuser: Planlagt, Pågår, Ferdig. Ferdig kan gjenåpnes; ferdigdato håndteres konsekvent. Oppdragsnummer skal være unikt og stabilt lokalt, for eksempel JB-0001, og må ikke baseres på antall eksisterende oppdrag.

Kundeendringer må ikke endre arbeidsadressen automatisk på et eksisterende oppdrag. Hindre sletting av kunder med tilknyttede oppdrag og forklar hvorfor. Sletting av oppdrag krever bekreftelse og rydder også tilhørende registreringer og bildefiler. Firmaopplysninger kan være ufullstendige; ikke tving frem falske data for å generere rapport.

## 5. Skjermstruktur og enkelhet

Tre hovedområder: Oppdrag, Kunder og Innstillinger. På iPad brukes sidepanel og detaljvisning når plassen tillater det. Startsiden viser aktive oppdrag, søk, enkle statusfiltre og tydelig Nytt oppdrag-knapp. Ferdige oppdrag er tilgjengelige via filter.

Oppdragsdetaljer har oversikt, bilder, arbeid og materialer som tydelige seksjoner. Vis total tidsbruk og en tydelig Lag rapport-handling. Ikke bygg et komplisert dashboard. Tomtilstander skal forklare neste handling. Status må forstås uten farge alene.

## Milepæl 0 – prosjektkontroll

- [x] Kartlegg eksisterende filer, targets, SDK, deployment target og lagring.
- [x] Bekreft at et grunnleggende bygg fungerer før større endringer.
- [x] Lag en kort implementeringsplan og noter tekniske valg nederst i filen.
- [x] Bevar signing, team og bundle identifier. Ingen publisering eller kjøp skal skje automatisk.

Godkjent når: Utgangspunkt og eventuelle byggproblemer er dokumentert.

## Milepæl 1 – grunnstruktur og innstillinger

- [x] Opprett mappestruktur og navigasjon med JobsView, CustomersView og SettingsView.
- [x] Sett opp varig lokal lagring og synlige feilmeldinger ved lagringsfeil. Ikke nullstill databasen automatisk ved feil.
- [x] Legg til firmaprofil med valgfri logo.
- [x] Implementer språkvalg, system/lyst/mørkt og faktisk versjon/build fra Bundle.
- [x] Opprett String Catalog; alle synlige tekster skal lokaliseres, også rapporttekst, enheter og feilmeldinger.

Godkjent når: Appen starter på iPhone/iPad, valgene beholdes etter omstart og navigasjonen fungerer i begge utseender.

## Milepæl 2 – kunder og oppdrag

- [x] Opprett, rediger og søk etter kunde. Bare kundenavn er obligatorisk.
- [x] Opprett og rediger oppdrag. Tittel og kunde er obligatorisk; kunde kan opprettes i flyten.
- [x] Egen arbeidsadresse kan kopieres fra kunden og deretter endres uavhengig.
- [x] Implementer stabilt oppdragsnummer, status, datoer, søk og filtrering.
- [x] Kundevisningen viser kundens oppdrag.
- [x] Lag forståelige tomtilstander og trygg sletting.

Godkjent når: En kunde og flere oppdrag kan opprettes, finnes igjen og redigeres etter full omstart uten datatap.

## Milepæl 3 – bilder og dokumentasjon

- [x] Importer med PhotosPicker og ta bilder med kamera på støttede enheter.
- [x] Be om kameratilgang først når kamera brukes; gi lokalisert forklaring. Håndter avslag og simulator uten kamera.
- [x] Velg før/underveis/etter, skriv bildetekst og juster bilderekkefølge.
- [x] Vis miniatyrer og større bilde uten å laste alle originaler i minnet.
- [x] Bevar riktig rotasjon og lesbar kvalitet. Sett en fornuftig maksimal oppløsning og komprimering; dokumenter valget.
- [x] Fjern unødvendige metadata som GPS i eksporterte bilder. Registreringsdato skal ikke presenteres som verifisert opptaksdato.
- [x] Slett bilder med bekreftelse og rydd tilhørende filer. Feil ved import skal ikke etterlate en halv registrering.

Godkjent når: Bilder fra kamera og bibliotek vises riktig etter omstart, og avslag på tilgang håndteres uten krasj.

## Milepæl 4 – arbeid og materialer

- [x] Registrer, rediger og slett arbeidsdato, beskrivelse og tidsbruk.
- [x] Summer tidsbruk korrekt fra hele minutter.
- [x] Registrer, rediger og slett materialnavn, positiv mengde og enhet.
- [x] Valider tomme felt og ugyldige tall med korte forklaringer ved feltet.
- [x] Ingen tvungen klokkeslettregistrering, priser eller MVA.

Godkjent når: Flere arbeidsdager og materiallinjer kan registreres; summer og desimaler stemmer på norsk og engelsk.

## Milepæl 5 – kunderapport som PDF

- [x] Lag enkel rapportinnstilling for å inkludere/utelate bilder, arbeidslogg og materialer.
- [x] Forhåndsvis faktisk PDF før deling eller utskrift.
- [x] Ta med firma/logo når tilgjengelig, rapportdato, oppdragsnummer, status, kunde, arbeidssted og beskrivelse.
- [x] Vis arbeid per dato og total tidsbruk, materialer med mengde/enhet og valgte bilder med kategori/bildetekst.
- [x] Legg til sidetall og konsekvente marger. Håndter lange tekster, mange bilder, store tabeller og sideskift uten avkuttet innhold.
- [x] Utelat tomme seksjoner. En rapport uten bilder skal også være ryddig.
- [x] Bruk font/rendering som viser norske og internasjonale tegn korrekt.
- [x] Bruk tydelig tittel Oppdragsrapport, uten fakturanummer, betalingskrav eller sertifiseringspåstander.
- [ ] Del via systemets delingsark og skriv ut via systemets utskriftsdialog. Kontroller presentasjon på iPad.
- [x] Lag trygt filnavn med oppdragsnummer og dato. Eksport er et øyeblikksbilde og skal ikke endres når oppdraget redigeres.

Godkjent når: En flersidig PDF med lange tekster og minst 20 bilder kan åpnes, deles og forhåndsvises for utskrift uten manglende innhold. Kontroller fysisk utskrift hvis skriver er tilgjengelig; ellers noter at den gjenstår.

## Milepæl 6 – sikkerhetskopiering og gjenoppretting

- [x] Eksporter en versjonert sikkerhetskopi med kunder, oppdrag, logger, materialer, firma, logo og bilder via systemets filvelger/delingsark.
- [x] Bruk et dokumentert arkivformat med manifest og schemaVersion. Ikke kopier en aktiv database ukritisk.
- [x] Importer via filvelger. Valider format, versjon, referanser og alle bildefiler før eksisterende data endres. Avvis usikre arkivstier og urimelige størrelser.
- [x] Første versjon bruker full erstatning, ikke sammenslåing. Vis antall kunder/oppdrag og tydelig bekreftelse før gjenoppretting.
- [x] Tilby eksport av nåværende data først. Gjenoppretting skal være atomisk eller ha sikker tilbakeføring ved feil.
- [x] Vis kort at sikkerhetskopien inneholder kundeopplysninger og bilder; ikke påstå at den er kryptert hvis den ikke er det.
- [x] Gjennomfør rundturstest: eksporter, gjenopprett i separat testlager og sammenlign antall, relasjoner, timer og bildefiler. Ødelagt sikkerhetskopi skal bevare eksisterende data.

Godkjent når: Hele datasettet med bilder kan gjenopprettes, og feilaktig import ikke skader eksisterende oppdrag.

## Milepæl 7 – demonstrasjonsdata og brukertest

- [x] Legg til valgfritt Last inn eksempeloppdrag i Innstillinger. Ikke automatisk ved oppstart og ikke flere kopier ved gjentatte trykk.
- [x] Tre tydelig fiktive oppdrag: terrassereparasjon, maling av rom og generell service.
- [x] Bruk fiktive kunder uten ekte kontaktinformasjon og illustrative eksempelbilder med rett til bruk. Eksempeldata merkes også i PDF.
- [x] Eksempeldata kan fjernes separat uten å slette ekte registreringer.
- [x] Legg til en kort hjelpeside om oppdrag, rapport og sikkerhetskopi.
- [ ] Kontroller stor tekst, VoiceOver-etiketter, kontrast, tastatur, liggende iPad og tydelige trykkflater.
- [ ] Test primærflyten uten nett, avbrutt registrering, avvist kameratilgang, manglende bilder og gjenåpning av ferdig oppdrag.
- [x] Legg til fokuserte automatiske tester for tidsberegning, unike oppdragsnumre, lagringsrelasjoner og sikkerhetskopiering. Unngå tester som bare gjentar UI-koden.
- [x] Bygg for relevante targets og dokumenter simulator-/enhetstester. Test på fysisk iPhone og iPad når tilgjengelig.

Godkjent når: En testperson kan opprette oppdrag og lage en rapport uten veiledning. Uavklarte problemer står i loggen.

## 6. Demo med håndverker

La testpersonen gjennomføre et lite faktisk eller fiktivt oppdrag. Noter:

1. Hva bruker du til dokumentasjon i dag?
2. Hvilke opplysninger savner du i oppdraget eller rapporten?
3. Hva er unødvendig eller tungvint?
4. Ville du sendt denne rapporten til kunden? Hvorfor/hvorfor ikke?
5. Ville du brukt appen på neste oppdrag, og hva måtte vært annerledes?
6. Foretrekker du engangskjøp eller abonnement, og hvilken pris ville du vurdert?

Ikke bygg alle ønskene med en gang. Velg én målgruppe etter tilbakemeldinger og identifiser den viktigste gjentatte arbeidsflyten. Fagspesifikke maler kommer først da.

## 7. Senere vurderinger – ikke del av prototypen

- Fagmaler og egne sjekklister.
- Prisoverslag med brukerens egne satser.
- iCloud-synk for samme bruker, med gjennomtenkt bilde- og konflikthåndtering.
- Flerbruker og kontortilgang krever en egen dataløsning og tilgangsmodell.
- Betalingsmodell, StoreKit og gjenopprett kjøp etter validering av behov.
- App Store-navn, ikon, personvernside, supportside og publiseringsmateriell.

## 8. Ferdigkriterium for prototypen

Prototypen er klar når primærflyten fungerer offline, data og bilder overlever omstart, en lesbar rapport kan deles/skrives ut, sikkerhetskopi kan gjenopprettes og norsk/engelsk samt begge enhetstypene er kontrollert. Publisering er et eget senere trinn.

## 9. Fremdriftslogg – vedlikeholdes av Codex

| Dato | Milepæl | Utført | Kontrollert | Gjenstår/begrensninger |
| --- | --- | --- | --- | --- |
| 2026-10-25 | Plan | Første milepælfil opprettet | Gjennomgått for omfang og sammenheng | Implementering ikke startet |
| 2026-10-25 | 0 | Kartlagt ett app-target, filer, bygginnstillinger og tomt utgangspunkt uten lagring | Grunnbygg fullført med iOS Simulator SDK 27.1 og deployment target 27.0 | Ingen test-target i prosjektet; signing, team og bundle-ID er uendret |
| 2026-10-25 | 1 | Lagt til adaptiv navigasjon, SwiftData-firmaprofil, administrert logofil, språk- og utseendevalg, versjon/build og String Catalog for nb/en/th | Xcode-diagnoser uten feil, sluttbygg godkjent og iPhone 17 Pro-simulator bekreftet navigasjon, norsk/mørkt utseende samt firmadata og valg etter relansering | Ingen kvalifisert iPad-simulator var tilgjengelig; fysisk iPhone/iPad og logoimport er ikke testet. Senere funksjoner tilhører milepæl 2–7 |
| 2026-10-25 | 2 | Lagt til kunder og oppdrag med redigering, søk, statusfilter, stabil sekvensteller, uavhengig arbeidsadresse, tomtilstander og trygg sletting | Sluttbygg godkjent; iPhone 17 Pro-simulator bekreftet kunde, to oppdrag (JB-0001/JB-0002), adresseuavhengighet, status/ferdigdato, søk/filter, kundens oppdrag og sperret kundesletting | Simulatoren ble bakgrunnsaktivert, ikke kaldstartet; bare Ferdig-filteret ble interaksjonstestet; fysisk enhet/iPad gjenstår |
| 2026-10-25 | 3 | Lagt til PhotosPicker, kamera med behovsstyrt tilgang, kategorier/bildetekst/rekkefølge, administrerte JPEG-filer, nedskalerte visninger og transaksjonssikker import/sletting | Sluttbygg godkjent; iPhone 17 Pro-simulator bekreftet import av to bilder, miniatyr/storvisning, redigering, omorganisering, relanseringspersistens, sletting og tydelig kamera-utilgjengelighet | Kameraopptak og avvist tillatelse må testes på fysisk enhet. Rotasjon/GPS-fjerning er implementert via normalisert nytegning til maks 2400 px og JPEG-kvalitet 0,82, men separat metadata-snutt kunne ikke kjøres i Xcode-miljøet |
| 2026-10-25 | 4 | Lagt til arbeidslogg og materialer med redigering, bekreftet sletting, validering, fritekstenhet og lokal desimalparsing | Sluttbygg og iPhone 17 Pro-simulator godkjent; 1 t 30 min + 45 min ble 2 t 15 min, redigering/sletting virket, norsk `1,5` ble lagret/vist korrekt, og gjenværende data overlevde relansering | Ingen fysisk enhet/iPad testet; separat snippet-kjøring tidsavbrøt, men samme beregning og desimalflyt ble verifisert i appen |
| 2026-10-25 | 5 | Lagt til valgbart PDF-innhold, A4-generator med sikker paginering, faktisk PDF-forhåndsvisning, lokaliserte rapporttekster, deling, utskrift og unike øyeblikksbildefiler | Sluttbygg godkjent; isolert 27-siders rapport med lang norsk/thai-tekst, 25 arbeidslinjer, 30 materialer og 20 bilder åpnet uten genereringsfeil. iPhone 17 Pro-simulator bekreftet norsk PDF, tom/full rapport, sidetall, bildesideskift, delingsvalg og A4-utskriftsdialog med trygg avbrytelse | Ingen kvalifisert iPad-simulator eller fysisk skriver/enhet var tilgjengelig. Delingspopoveren var synlig i UI-hierarkiet, men ikke visuelt rendret av simulatorverktøyet. iPad-presentasjon og fysisk utskrift/deling gjenstår; milepæl 6 er ikke startet |
| 2026-10-25 | 6 | Lagt til versjonert JSON-sikkerhetskopi med manifest/schemaVersion, SHA-256-verifiserte bilder/logo, størrelses- og referansevalidering, systemeksport, lokal-kopi-import, innholdsoversikt, full erstatning og tilbakeføring av database/filer ved feil | Sluttbygg godkjent; separat minnelager-rundtur bekreftet kunder, oppdrag, relasjoner, 135 minutter, materiale, sekvensteller, foto og logo. Skadet fil ble avvist uten dataendring. iPhone-simulator fullførte eksport til Files, import, norsk forhåndsvisning/bekreftelse, gjenoppretting og norsk suksessvarsel; oppdrag, relasjoner, arbeid, materiale og bilde var intakte etterpå | Ingen fysisk enhet/iPad testet. SwiftData logger advarsler om kortvarig lesing av ugyldiggjorte modellreferanser mens full erstatning oppdaterer aktive visninger, men simulatorflyten fullførte korrekt uten datatap. Milepæl 7 er ikke startet |
| 2026-10-25 | 7 | Lagt til tre selektivt slettbare eksempeloppdrag med programmatisk tegnede illustrasjoner, PDF-merking, hjelpeside og Swift Testing-mål. Thai er fjernet fra språkvalget etter avklaring; appen støtter norsk bokmål og engelsk | App- og testbygg godkjent; 4 av 4 kjernetester bestått. iPhone 17 Pro-simulator bekreftet migrering av eksisterende lager uten datatap, tre eksempeloppdrag ved siden av ekte data, separat fjerningshandling, hjelpeside, forståelige VoiceOver-etiketter og listerader på minst 52 pt | Full test av gjentatt lasting, sletting, stor tekst, kontrast, tastatur, liggende iPad, kameratilgang og hele primærflyten ble blokkert av «invalid screen scale» og et Xcode-varsel som må godtas. Verktøylinjeknappene Filter/Nytt oppdrag rapporterte ca. 40×36/37×36 pt og bør kontrolleres mot 44×44. Ingen fysisk iPhone/iPad eller ekstern testperson var tilgjengelig; de to kontrollpunktene står derfor åpne |

## 11. Implementeringsplan og tekniske valg

1. Etabler appskall og tomtilstander for Oppdrag, Kunder og Innstillinger med `NavigationSplitView`, slik at samme navigasjon kan tilpasse seg iPhone og iPad.
2. Bruk SwiftData bak `PersistenceService` med en eksplisitt filplassering i Application Support og CloudKit avslått. Ved oppstartsfeil vises en feiltilstand; lageret slettes eller nullstilles aldri automatisk.
3. Lagre firmaprofilen strukturert i SwiftData. Logo lagres som en administrert fil under Application Support, mens modellen bare lagrer relativ filreferanse.
4. Lagre språk og utseende i `AppStorage`, bruk valgt `Locale` og `ColorScheme` i appens rot, og les versjon/build fra appens `Bundle`.
5. Hold all synlig apptekst i `Localizable.xcstrings` med norsk bokmål, engelsk og thai. Rapporttittel og planlagte materialenheter er opprettet nå, men rapportfunksjonen implementeres først i milepæl 5.

## 10. Tekst til første Codex-oppgave

Les JOBBBEVIS_MILESTONES.md og eventuelle AGENTS.md. Undersøk mitt eksisterende Xcode-prosjekt. Implementer milepæl 0 og 1 for JobbBevis, med SwiftUI for iPhone og iPad, lokal lagring, strukturert kode, JobsView som startside og innstillinger for norsk/engelsk/thai, system/lyst/mørkt og versjon/build. Bevar signing og bundle identifier. Bygg prosjektet og rett feil som skyldes endringene. Oppdater fremdriftsloggen og oppgi hva som er kontrollert. Ikke start senere milepæler i denne første oppgaven.
