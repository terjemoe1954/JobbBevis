# HandyMe – plan for hovedentreprenør med underleverandører

## Formål og avgrensning

Denne planen vurderer dagens JobbBevis/HandyMe-app opp mot behovet for å administrere ett hovedprosjekt der HandyMe er hovedentreprenør og flere underleverandører utfører egne fag.

Hvasser-prosjektet `HM-2026-001` brukes som testscenario. Den tidligere filen `HandyMe_Hvasser_Testplan.md` finnes ikke lenger i prosjektets rotmappe. Vurderingen bygger derfor på filene i `HandyMe_Registrering`, spesielt prosjekt-, arbeidspakke-, time-, kontroll-, vare-, handle- og reiseregistrene samt anbuds- og ordrebekreftelsesutkastene.

Planen foreslår ingen import og gjør ingen endringer i eksisterende appdata.

### Testscenario og fire fagområder

Første versjon bør støtte disse fire operative fagområdene:

1. Tømrer – 340 planlagte timer, inkludert rigg, kjøkken og veranda.
2. Maler – 210 planlagte timer, overflatearbeider.
3. Elektro – 180 planlagte timer, elektrisk anlegg, lys og varme/styring.
4. VVS – 120 planlagte timer, vannrør og bereder.

Prosjektledelse på 55 timer bør ligge som et eget internt fag eller en hovedentreprenørkostnad, ikke som en femte underleverandør. De åtte arbeidspakkene i testgrunnlaget fordeles på disse fagene og prosjektledelse.

Prisgrunnlaget i vedleggene er:

- Arbeidspakker: kr 1 385 000 inkl. mva.
- Reserve 15 %: kr 207 750.
- Samlet budsjettramme: kr 1 592 750 inkl. mva.
- Reise: 4 560 km og 72 timer, foreløpig ikke priset eller fakturert.
- 905 timer er planlagte fagtimer, ikke utførte timer.

Timebudsjettet må ikke legges oppå arbeidspakkenes arbeidsbeløp uten at kalkylen uttrykkelig bruker timer som kostnadsgrunnlag. Ellers dobbeltelles arbeid.

## 1. Funksjoner som allerede finnes

### Kunder og oppdrag

- Kunde med kundenummer, kontaktinformasjon, adresse og organisasjonsnummer.
- Oppdrag med unikt oppdragsnummer, kunde, arbeidsadresse, beskrivelse, planlagt dato og status.
- Oppdrag kan arkiveres etter fakturering.
- Varsel ved like kunde-, leverandør-, vare- og oppdragsnavn, mens unike numre håndheves separat.
- Bilder med før-, under- og etterkategori.
- Arbeidslogg med dato, beskrivelse og utførte minutter.
- Materialregistrering med mengde, enhet, intern merknad og enhetspris.

### Leverandører og vareregister

- Leverandørregister med leverandørnummer og kontaktinformasjon.
- Vare kan knyttes til én leverandør.
- Vareregister har varenummer, navn, enhet og pris ekskl. mva.
- Vanlige material-enheter er lokaliserbare.
- Vare kan velges fra innkjøpslisten, oppdateres eller opprettes som ny vare.

### Innkjøpsliste

- Innkjøpslinjer er knyttet til oppdrag.
- Linjen inneholder leverandørnavn, vare, mengde, enhet, pris og merknad.
- En innkjøpslinje kan overføres til materialer og tilbakeføres uten duplikat.
- Total innkjøpskostnad ekskl. mva. vises separat og legges ikke automatisk til kundekalkylen.

### Kalkyle

- Enkel kalkyle på oppdragsnivå med:
  - estimerte timer × én timepris
  - materiallinjer
  - kilometer × én kilometersats
  - én mva.-sats
- Viser arbeid, materialer, kjøring, delsum, mva. og total.
- Oppdragsrapport kan inkludere bilder, arbeidslogg, materialer og prisoverslag.

### Ordrebekreftelse, faktura og regnskap

- Ordrebekreftelse kan genereres som PDF fra oppdragets gjeldende prisede arbeid, materialer og kjøring.
- Fakturautkast kan opprettes, redigeres og slettes før godkjenning.
- Godkjent faktura får løpenummer og låst snapshot av kunde, firma, linjer og priser.
- Fakturert oppdrag kan ikke slettes, bare arkiveres.
- Kreditnota for hel faktura finnes.
- Fakturalinjer kan eksporteres til generell CSV for regnskap.
- Regnskapsrapport og registerrapporter finnes som PDF.

### Datasikkerhet

- SwiftData-modeller med relasjoner og slettingsregler.
- Sikkerhetskopi og gjenoppretting inkluderer kunder, oppdrag, registreringer, varer, leverandører og salgsdokumenter.
- Fakturasnapshot bevarer historiske dokumentdata selv om oppdraget senere endres.

## 2. Funksjoner som mangler

### Prosjektstruktur og fag

- Ingen egen hovedprosjektmodell adskilt fra et enkelt oppdrag.
- Ingen fagområder eller ansvarsmatrise.
- Ingen arbeidspakker med nummer, fag, omfang, budsjett, status, rekkefølge og avhengigheter.
- Ingen skille mellom planlagte timer, utførte timer og fakturerbare timer.
- Ingen rom, bygningsdeler eller soner for fordeling av arbeid.
- Ingen milepæler, fremdriftsprosent eller planlagt start/slutt per fag.

### Underleverandører

- Dagens `Supplier` er primært en vareleverandør og mangler rollen som underentreprenør.
- Ingen kobling mellom underleverandør og prosjekt, fag eller arbeidspakke.
- Ingen lagring av underleverandørens organisasjonsnummer, fagkompetanse, kontraktsstatus eller kontaktperson per prosjekt.
- Ingen innhenting og sammenligning av tilbud fra underleverandører.
- Ingen underentreprise/innkjøpsordre med avtalt beløp, mva., betalingsplan eller forbehold.
- Ingen registrering av underleverandørfakturaer, attestasjon eller betalt-status.
- Ingen sammenligning av budsjett, bestilt, mottatt faktura og prognose.
- Ingen påslag eller dekningsbidrag per underleverandør, fag eller arbeidspakke.

### Anbud og avtale

- Ingen vedvarende anbuds-/tilbudsmodell.
- Ingen tilbudsnummer, revisjon, gyldighetsdato, status eller versjonshistorikk.
- Ingen tilbudslinjer fordelt på arbeidspakker.
- Ingen egne forbehold, opsjoner, reserve eller kundegodkjenning.
- Ingen lagret kobling fra akseptert tilbud til ordrebekreftelse.
- Ordrebekreftelsen er en øyeblikks-PDF og lagres ikke som et versjonert forretningsdokument.
- Ingen signatur, akseptdato eller dokumentasjon på hvem som godkjente.

### Kalkyle og økonomi

- Bare én timepris og ett samlet timeestimat per oppdrag.
- Ingen kostpris versus salgspris.
- Ingen separate material-, arbeid- og underleverandørkostnader per arbeidspakke.
- Ingen støtte for beløp som allerede inkluderer mva.; dagens kalkyle forventer priser ekskl. mva.
- Ingen eksplisitt budsjettreserve som ikke er bestilt eller fakturerbar.
- Ingen varsling mot dobbeltelling av arbeidspakker og timebudsjett.
- Ingen reiseplan med antall turer, én-veis avstand/tid, overnatting eller status planlagt/gjennomført.
- Ingen budsjett–faktisk–prognose eller avviksanalyse.
- Ingen betalingsplan, forskudd, delbetaling eller milepælsfakturering.

### Fakturagrunnlag

- Fakturagrunnlaget hentes direkte fra oppdragets samlede estimerte timer, materialer og kjøring.
- Utførte arbeidslogger brukes ikke som fakturagrunnlag.
- Ingen valg av godkjente arbeidspakker, endringer eller perioder til faktura.
- Bare én ordinær faktura kan utstedes per oppdrag.
- Ingen del- eller sluttfaktura, tidligere fakturert beløp eller gjenstående kontraktsverdi.
- Ingen delkreditnota eller korrigering av enkeltlinjer.
- Underleverandørkostnader og hovedentreprenørens påslag er ikke synlige i grunnlaget.

### Endringer, kvalitet og overlevering

- Ingen endringsordre med kundegodkjenning før utførelse.
- Ingen kontrollpunkter, sjekklister eller avvik.
- Ingen ansvarlig part og frist per kontrollpunkt.
- Ingen dokumentkrav per fag, for eksempel el-samsvarserklæring og VVS-dokumentasjon.
- Ingen FDV-pakke, sluttkontroll eller formell overlevering.
- Ingen skille mellom illustrasjonsbilder og faktisk prosjektdokumentasjon.

## 3. Forslag til forbedringer

### Anbefalt konsept

Behold dagens `JobRecord` som hovedprosjekt i første utvidelse. Legg arbeidspakker, fag, prosjektaktører og dokumenter under dette objektet. Det gir minst mulig risiko og lar enkle oppdrag fortsette å fungere uten at brukeren må fylle ut entreprenørfelter.

Aktiver «Hovedentreprise» som en valgfri prosjektmodus. Vanlige småoppdrag beholder dagens enkle skjermbilder. Når modusen er aktiv, vises nye seksjoner for fag, arbeidspakker, underleverandører, fremdrift, økonomi og kvalitet.

### Foreslått prosjektoversikt

Oppdragsdetaljen bør utvides med separate, små SwiftUI-seksjoner:

- Oversikt: kunde, adresse, kontraktsstatus og nøkkeldatoer.
- Fag og underleverandører: fire fagkort med ansvarlig firma og status.
- Arbeidspakker: budsjett, fremdrift og avvik.
- Økonomi: kontraktsverdi, reserve, bestilt, påløpt, fakturert og prognose.
- Innkjøp: bestilt, mottatt og overført til materialer.
- Kvalitet: kontrollpunkter, avvik og påkrevd dokumentasjon.
- Dokumenter: tilbud, ordrebekreftelse, endringsordre, faktura og overlevering.

Hver seksjon bør være en separat `View` med smale data-innganger, slik at den store prosjektoversikten ikke må tegnes på nytt ved enhver liten endring.

### Arbeidsflyt for Hvasser

1. Opprett `HM-2026-001` som hovedprosjekt i tilbudsstatus.
2. Opprett fagene tømrer, maler, elektro og VVS; prosjektledelse registreres som internt fag.
3. Opprett de åtte arbeidspakkene og fordel dem på fag.
4. Registrer arbeidspakkenes material- og arbeidsbudsjett inkl. mva. som avtale-/budsjettgrunnlag.
5. Registrer 905 timer som planlagte timer per fag, aldri som utført arbeidslogg.
6. Registrer reise som plan med 12 tur-retur, 4 560 km og 72 timer, uten salgspris før avtale.
7. Knytt aktuelle underleverandører til elektro og VVS; tømrer/maler kan være interne eller eksterne.
8. Opprett kontrollpunktene fra testgrunnlaget med ansvar og dokumentkrav.
9. Opprett tilbudsrevisjon 1 som utkast. Reserven vises separat og er ikke fakturerbar.
10. Etter simulert aksept låses tilbudsrevisjonen og danner ordrebekreftelse og kontraktsgrunnlag.
11. Arbeid, innkjøp, endringsordre og underleverandørfakturaer oppdaterer prosjektprognosen.
12. Fakturagrunnlag bygges fra godkjente kontrakts-/endringslinjer eller godkjent fremdrift, ikke ved å summere alle lagrede kostnader ukritisk.

### Regler som bør håndheves

- Planlagt, bestilt, utført, godkjent og fakturert skal være separate tilstander.
- Kostpris og salgspris skal aldri bruke samme felt.
- Beløp må ha eksplisitt mva.-behandling.
- Reserve skal ikke bli fakturalinje uten godkjent endringsordre.
- En arbeidspakke kan bruke enten fastprisgrunnlag eller timer/materialer som salgsgrunnlag; appen skal advare mot dobbeltelling.
- Underleverandørtilbud og fakturaer er kostnader. Kundetilbud og salgsfakturaer er inntekter.
- Dokumenter som godkjennes, skal lagres som uforanderlige snapshots med revisjon og dato.
- Fakturagrunnlag skal vise kilde på hver linje: kontrakt, endringsordre, utført arbeid, materiale eller reise.

## 4. Nødvendige endringer i datamodellene

Navnene under er forslag; endelig navngivning bør fastsettes før implementering.

### Utvidelse av `JobRecord`

- `projectMode`: enkeltoppdrag eller hovedentreprise.
- `contractStatus`: forespørsel, tilbud, tilbud sendt, akseptert, aktivt, overlevering, avsluttet.
- `plannedStart`, `plannedEnd`, `actualStart`, `actualEnd`.
- `contractValueExcludingVAT` og/eller kontraktsverdi som beregnes fra godkjent tilbud.
- `contingencyPercent` og `contingencyAmount` som separat, ikke-fakturerbar reserve.
- areal-/prosjektmetadata kan eventuelt ligge i en egen `ProjectSpecification`.

### Ny `Trade` / `ProjectTrade`

- Stabil ID, kode og navn.
- Type: tømrer, maler, elektro, VVS, prosjektledelse eller egendefinert.
- Intern/ekstern utførelse.
- Ansvarlig prosjektaktør.
- Planlagte og godkjente timer, start/slutt og status.

### Ny `ProjectParty` / `SubcontractAssignment`

Knytter et firma til et prosjekt og en rolle uten å overbelaste vareregisterets leverandørrelasjon.

- prosjekt, leverandør/firma og fag.
- rolle: underentreprenør, vareleverandør, rådgiver eller intern.
- prosjektspesifikk kontaktperson.
- organisasjonsnummer og kvalifikasjons-/dokumentreferanser.
- kontraktsstatus, avtaledato og betalingsbetingelser.
- avtalt kostnad, mva., påslag og prognose.

`Supplier` bør utvides med organisasjonsnummer og leverandørtype, men prosjektspesifikke avtaleverdier skal ligge på koblingsmodellen.

### Ny `WorkPackage`

- unikt nummer innen prosjekt, tittel og detaljert omfang.
- prosjekt og fag.
- ansvarlig prosjektaktør.
- status og fremdriftsprosent.
- planlagt/faktisk start og slutt.
- prismodell: fastpris, regning eller intern budsjettpost.
- materialbudsjett og arbeidsbudsjett med eksplisitt mva.-grunnlag.
- kostbudsjett, salgsbudsjett, bestilt, påløpt og prognose.
- rekkefølge og eventuelle avhengigheter.
- markering for om timer/materialer skal inngå i salgsgrunnlaget.

### Plan og faktisk registrering

- Ny `LaborBudget` eller planfelter knyttet til fag/arbeidspakke.
- `WorkEntry` utvides med valgfri fag-, arbeidspakke- og utførerreferanse samt godkjenningsstatus.
- Ny `TravelPlan`/`TravelEntry` med planlagt eller gjennomført status, turer, km, timer, sats og fakturerbarhet.
- `MaterialEntry` utvides med arbeidspakke, kostpris, salgspris, leverandør og godkjenningsstatus.

### Innkjøp og underleverandørkostnader

- `PurchaseItem` bør knyttes til vare-ID, leverandør-ID og arbeidspakke i stedet for bare tekstfelt.
- Separate felt for bestilt, mottatt, bestilt dato, mottatt dato og faktisk kostnad.
- Ny `SupplierQuote` med revisjon og tilbudslinjer.
- Ny `PurchaseOrder`/`Subcontract` med låst avtalesnapshot.
- Ny `SupplierInvoice` med fakturanummer, dato, forfall, beløp, arbeidspakke, attestasjon og betalingsstatus.

### Tilbud og dokumenter

- Ny `Quote` med tilbudsnummer, revisjon, dato, gyldighet, status, forbehold og akseptinformasjon.
- Ny `QuoteLine` med arbeidspakke, beskrivelse, mengde, enhet, pris og mva.
- Ny `OrderConfirmation` som snapshot av akseptert tilbud og avtalte datoer.
- Ny `ChangeOrder` og `ChangeOrderLine` med årsak, konsekvens, status og godkjenning.
- En generell `ProjectDocument` kan lagre filreferanse, dokumenttype, revisjon, status og hash/snapshot.

### Faktura

- `InvoiceRecord` må tillate flere fakturaer per prosjekt.
- Faktura bør ha type: forskudd, del, milepæl, slutt eller kreditnota.
- Ny kobling fra fakturalinje til kilde-ID og kildetype.
- Lagre tidligere fakturert og gjenstående kontraktsverdi i fakturasnapshotet.
- Støtt delkreditering via egne kreditnotalinjer.
- Dagens uforanderlige snapshot-prinsipp bør beholdes.

### Kvalitet og overlevering

- Ny `ChecklistItem` med ansvarlig, frist, status, kommentar og dokumentreferanse.
- Ny `Deviation` for avvik og lukking.
- Ny `DocumentRequirement` per fag, for eksempel samsvarserklæring og FDV.
- Overleveringsstatus og kundesignatur bør lagres som eget snapshot.

### Migrering, sikkerhetskopi og sletting

- Alle nye modeller og felt må legges til SwiftData-containeren.
- Eksisterende oppdrag migreres som `simpleJob` med uendrede beregninger.
- Nye relasjoner bør være valgfrie i første migrering.
- Sikkerhetskopiens formatversjon må økes og være bakoverkompatibel.
- Validering må kontrollere unike dokumentnumre og gyldige prosjektkoblinger.
- Slettingsregler må beskytte aksepterte tilbud, kontrakter, fakturaer og dokumentasjon.

## 5. Milepæler for implementering og testing

### Milepæl 0 – beslutninger og fasit for kalkyle

Før kodeendring må følgende godkjennes:

- Om de fire fagene alltid er faste eller kan tilpasses.
- Om `Supplier` skal representere både vareleverandør og underentreprenør.
- Hvordan beløp lagres: alltid ekskl. mva. med mva.-sats anbefales.
- Om Hvasser-arbeidspakkene er salgspris/budsjett, og hvordan reserve behandles.
- Hvilke faktureringsformer som trengs først: fastpris, delbetaling eller medgått.
- Om intern tømrer/maler skal registreres som prosjektaktør eller bare fag.

**Test:** Dokumentert kalkyleeksempel som kommer til nøyaktig kr 1 592 750 uten dobbeltelling, og der reise fortsatt er kr 0 inntil den prises.

### Milepæl 1 – fag, prosjektaktører og arbeidspakker

- Legg til prosjektmodus, fag, prosjektaktører og arbeidspakker.
- Lag prosjektoversikt med fire fag og åtte Hvasser-arbeidspakker.
- Behold dagens enkle oppdragsmodus.
- Oppdater sikkerhetskopi og slettingsregler.

**Tester:**

- Migrering av eksisterende database uten datatap.
- Opprett, rediger og slett utkast til arbeidspakke.
- Leverandør kan brukes som vareleverandør uten å bli underentreprenør.
- Samme firma kan ha flere fagroller i ett prosjekt uten duplikat.
- Hvasser-pakkene summerer til kr 1 385 000 inkl. mva.

### Milepæl 2 – kostnad, plan, fremdrift og reise

- Skill kostpris, salgspris, budsjett og prognose.
- Legg til planlagte timer per fag og arbeidspakke.
- Knytt utførte timer og materialer til fag/arbeidspakke.
- Legg til reiseplan og gjennomførte reiser.
- Vis budsjett–faktisk–prognose.

**Tester:**

- 905 timer vises som planlagt og 0 som utført ved prosjektstart.
- Arbeidspakkepris og timebudsjett dobbeltelles ikke.
- 12 tur-retur gir 4 560 km og 72 timer.
- Uten km-/timepris påvirker reisen ikke kundetotalen.
- Kostnads- og salgsrapporter viser ulike tall korrekt.

### Milepæl 3 – underleverandørtilbud, bestilling og faktura

- Tilbud fra underleverandører og sammenligning.
- Underentreprise/innkjøpsordre per fag eller arbeidspakke.
- Registrer og attester leverandørfakturaer.
- Beregn påslag, dekningsbidrag og prognose.

**Tester:**

- Elektro- og VVS-tilbud kan sammenlignes uten å endre kundetilbudet.
- Bare valgt og godkjent tilbud blir bestilling.
- Leverandørfaktura påvirker kostnad, ikke automatisk kundens fakturagrunnlag.
- Avvik mellom avtalt og fakturert kostnad varsles.

### Milepæl 4 – kundetilbud, ordrebekreftelse og endringsordre

- Versjonert tilbud med arbeidspakker, reserve, forbehold og gyldighet.
- Akseptflyt og låst snapshot.
- Ordrebekreftelse genereres fra akseptert revisjon.
- Endringsordre med kundegodkjenning.

**Tester:**

- Utkast kan redigeres; akseptert revisjon kan ikke endres.
- Ny revisjon endrer ikke tidligere dokument.
- Reserve på kr 207 750 vises separat og er ikke bestilt/fakturerbar.
- Ordrebekreftelsen viser referanse til riktig tilbudsrevisjon.
- Endringsordre påvirker kontraktsverdi først etter godkjenning.

### Milepæl 5 – del- og sluttfakturering

- Flere fakturaer per prosjekt.
- Fakturagrunnlag fra kontrakt, godkjent fremdrift og endringsordre.
- Tidligere fakturert og gjenstående beløp.
- Delkreditnota.

**Tester:**

- To delfakturaer og én sluttfaktura kan ikke overstige godkjent grunnlag.
- Samme arbeidspakke kan ikke faktureres dobbelt.
- Fakturasnapshot forblir uendret etter senere prosjektendringer.
- Regnskaps-CSV inneholder alle faktura- og kreditnotalinjer med korrekt mva.

### Milepæl 6 – kvalitet, dokumentasjon og overlevering

- Kontrollpunkter, avvik og dokumentkrav.
- Fagspesifikke dokumenter.
- FDV- og overleveringspakke.

**Tester:**

- Hvassers seks kontrollpunkter får korrekt ansvar og status.
- Prosjektet kan ikke markeres ferdig før obligatoriske punkter er lukket eller eksplisitt fraveket.
- El-samsvarserklæring og VVS-dokumentasjon er sporbare til riktig fag.
- Overleveringsrapporten inneholder godkjente bilder og dokumenter.

### Milepæl 7 – helhetlig akseptansetest

Kjør hele Hvasser-scenarioet fra forespørsel til overlevering:

1. Kunde og prosjekt.
2. Fire fag og prosjektledelse.
3. Åtte arbeidspakker.
4. Planlagte timer og reise.
5. Underleverandørtilbud og bestillinger.
6. Kundetilbud, aksept og ordrebekreftelse.
7. Arbeidsregistrering, innkjøp, kontrollpunkter og endringsordre.
8. Del- og sluttfakturering.
9. Regnskapseksport, FDV og overlevering.
10. Sikkerhetskopi på én enhet og gjenoppretting på en annen.

Akseptansekriteriet er at alle summer, statuser, relasjoner og dokumentrevisjoner er identiske etter gjenoppretting, og at ingen planlagte timer/reiser feilaktig vises som utført eller fakturert.

## Anbefalt første leveranse

Godkjenn først milepæl 0 og 1. De etablerer riktig struktur uten å endre dagens fakturering. Kalkyle- og dokumentflyten bør ikke bygges om før vi har godkjent hvordan fastpris, medgått tid, underleverandørpåslag, reserve og delbetaling skal virke sammen.

Ingen implementering bør starte før denne planen og beslutningene i milepæl 0 er godkjent.
