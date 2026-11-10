# iOS-funksjonskart for HandyMe Web

Dette dokumentet er M0-kartlegging av den eksisterende iOS-appen. Det beskriver observert kildekode, ikke en ny webdatamodell. Ingen Swift-filer, Xcode-innstillinger, iCloud-data eller backupformat er endret.

## Sentrale modeller

| Område | iOS-modell og viktige felt | Kilde |
|---|---|---|
| Kunder | `Customer`: UUID, kundenummer, navn, kontaktperson, telefon, e-post, adresse, organisasjonsnummer, tidsstempler og relasjon til oppdrag. Sletting nektes mens kunden har oppdrag. | `JobbBevis/JobbBevis/Models/Customer.swift:4` |
| Varer / varekatalog | `ProductCatalogItem`: UUID, varenummer, leverandør/leverandørrelasjon, navn, valgfri standardmengde, enhet, enhetspris og tidsstempler. | `JobbBevis/JobbBevis/Models/ProductCatalogItem.swift:4` |
| Materialenheter | Forhåndsdefinerte enheter omfatter stk., mm, cm, m, m², m³, liter, kg, time, pakke, spann, eske, sett og rull. Egne enhetstekster støttes i skjemaet. | `JobbBevis/JobbBevis/Models/MaterialEntry.swift:4`; `JobbBevis/JobbBevis/Views/MaterialEntryFormView.swift:174` |
| Prosjekt / oppdrag | `JobRecord`: UUID, jobbnummer, tittel, arbeidsadresse, beskrivelse, planlagt dato, status, fullføringsdato, arkivering, kunde, prosjektmodus og prisfelter. Har relasjoner til bilder, arbeid, materialer, innkjøp, fag, prosjektparter og arbeidspakker. | `JobbBevis/JobbBevis/Models/JobRecord.swift:20` |
| Arbeid og timer | `WorkEntry`: dato, beskrivelse, varighet i hele minutter, valgfri kjørte kilometer og tidsstempler. Skjemaet krever beskrivelse og positiv varighet. | `JobbBevis/JobbBevis/Models/WorkEntry.swift:4`; `JobbBevis/JobbBevis/Views/WorkEntryFormView.swift:89` |
| Registrerte materialer | `MaterialEntry`: navn, positiv mengde, enhet, notat og valgfri enhetspris. En varekatalogpost kan fylle inn navn, enhet og pris. | `JobbBevis/JobbBevis/Models/MaterialEntry.swift:67`; `JobbBevis/JobbBevis/Views/MaterialEntryFormView.swift:126` |
| Planlagte innkjøp | `PurchaseItem`: leverandør, varenavn, mengde, enhet, enhetspris og overføringsstatus til materialer. Linjesum er mengde × enhetspris. | `JobbBevis/JobbBevis/Models/PurchaseItem.swift:4` |
| Firma og standardpriser | `CompanyProfile`: MVA-registrering, standard timepris og standard kilometerpris. Standardsatsene fylles inn ved oppretting av nytt oppdrag. | `JobbBevis/JobbBevis/Models/CompanyProfile.swift:4`; `JobbBevis/JobbBevis/Views/JobFormView.swift:199` |
| Tilbud og salgsdokumenter | Tilbud er en generert `SalesDocumentSnapshot` med linjer; det finnes ingen egen, vedvarende tilbudsmodell. Faktura og kreditnota lagrer et kodet, uforanderlig snapshot. | `JobbBevis/JobbBevis/Models/InvoiceRecord.swift:4`; `JobbBevis/JobbBevis/Services/SalesDocumentService.swift:47` |

## Brukerflyter som er relevante for webprototypen

1. En kunde opprettes og velges på et oppdrag.
2. Oppdraget får planlagte timer, timepris eks. MVA, planlagt kjøring, kilometerpris eks. MVA og eventuell MVA-sats.
3. Varer kan ligge i en global varekatalog. Planlagte innkjøpslinjer brukes ved tilbud; registrerte materiallinjer brukes ved ordre/faktura.
4. Faktisk arbeid registreres med dato, beskrivelse, timer/minutter og eventuell kjøring.
5. Prisoverslaget i oppdragsvisningen er basert på planlagte timer, registrerte materiallinjer og planlagt kjøring.
6. Tilbud genereres med estimatgrunnlag. Ordrebekreftelse og faktura genereres med registrert grunnlag.

Kilder: `JobbBevis/JobbBevis/Views/JobFormView.swift:75`, `JobbBevis/JobbBevis/Services/PriceEstimateCalculator.swift:13`, `JobbBevis/JobbBevis/Services/SalesDocumentService.swift:82`, `JobbBevis/JobbBevis/Views/SalesDocumentsView.swift:147`.

## Enkelt oppdrag og hovedentreprise

`ProjectMode` har to verdier: `simpleJob` og `mainContract`. Manglende lagret verdi tolkes som enkelt oppdrag, så enkelt oppdrag er bakoverkompatibel standard.

### Enkelt oppdrag

- Bruker kjernedataene på `JobRecord`: kunde, beskrivelse/status/datoer, planlagt prisgrunnlag, arbeid, materialer, kjøring, innkjøp og salgsdokumenter.
- Har ikke behov for fag, prosjektparter eller arbeidspakker.
- Dette samsvarer med avgrensningen for den første webversjonen.

### Hovedentreprise

- Utvider samme `JobRecord` med `ProjectTrade`, `ProjectParty` og `WorkPackage`.
- Fag har kode, navn, intern/ekstern-markør og planlagte timer.
- Prosjektparter kan være hovedentreprenør, underleverandør, materialleverandør, konsulent eller intern ressurs, og kan knyttes til leverandør og fag.
- Arbeidspakker har nummer, beskrivelse, status, datoer, fremdrift, planlagte timer, ansvarlig part og flere budsjettfelt.
- Arbeidspakkebudsjetter er uttrykkelig ikke med i prisestimat eller faktura.

Kilder: `JobbBevis/JobbBevis/Models/ProjectStructure.swift:4`, `JobbBevis/JobbBevis/Models/JobRecord.swift:78`, `JobbBevis/JobbBevis/Views/ProjectStructureView.swift:15`, `JobbBevis/JobbBevis/Views/ProjectStructureView.swift:201`.

## Uklarheter som må avklares før implementering

- `ProductCatalogItem.unitPrice`, materialpriser og innkjøpspriser har ikke et eget felt som uttrykkelig angir inkl./ekskl. MVA. Skjematekster angir at time- og kilometerpris er eks. MVA, og salgsdokumentene behandler alle enhetspriser som eks. MVA, men semantikken bør bekreftes for katalog- og materialpriser.
- Prisestimatet bruker registrerte `MaterialEntry`-linjer, mens tilbud bruker `PurchaseItem`-linjer. Om dette avviket er tilsiktet produktatferd må bekreftes før paritetstester.
- MVA-satsen er én sats per oppdrag og kopieres til alle dokumentlinjer. Det finnes ikke linjespesifikke satser eller eksplisitte fritakskoder.
- Det er ikke funnet rabatt, påslag, reisetid, bompenger, kost/losji eller andre reisekostnader i beregningsmodellen; bare kilometer × sats.
- Det finnes ingen egen lagret tilbudsstatus, tilbudsnummer eller akseptmodell i de gjennomgåtte modellene. Tilbudet ser ut til å være en generert PDF fra et øyeblikksbilde.
- Hovedentreprise har både `budgetExcludingVAT` og separate material-/arbeidsbudsjetter navngitt som inkludert MVA. Ingen regel kobler eller avstemmer disse feltene.

## Risiko for webparitet

- JavaScript-tall er binære flyttall, mens iOS bruker `Decimal`. Webappen bør bruke en eksplisitt desimalstrategi og tester for å unngå øredifferanser.
- Udefinert avrunding gjør at visningsavrunding og lagret/beregnet verdi lett kan blandes.
- Tilbudsgrunnlag, estimatgrunnlag og fakturagrunnlag er ikke identiske og må modelleres som separate, navngitte operasjoner.
- Hovedentreprisefeltene må ikke trekkes inn i M1–M5 ved et uhell; de er eldre/avanserte funksjoner som skal bevares i iOS, men holdes utenfor første webversjon.

## Foreslått trygg mappestruktur for M1

I tråd med milepælsdokumentet bør webprosjektet opprettes som et søsken til iOS-repoet, ikke inne i det:

```text
My Apps/
├── JobbBevis/       # eksisterende iOS-repo, urørt
└── HandyMe-Web/     # nytt, separat React/Vite-prosjekt
```

Ingen slik mappe er opprettet i M0. Plasseringen krever godkjenning før M1.
