# Beregningsregler kartlagt fra iOS

Dette dokumentet gjengir kun regler som kan spores til eksisterende Swift-kode. Uklarheter er markert; de skal ikke fylles med antakelser i webappen.

## Prisestimat

For `PriceEstimateCalculator.estimate(for:)` gjelder:

```text
arbeid = maxPositiv(planlagteTimer) × maxPositiv(timepris)
materialer = Σ(mengde × maxPositiv(valgfriEnhetspris))
kjøring = maxPositiv(planlagteKilometer) × maxPositiv(kilometerpris)
delsumEksMva = arbeid + materialer + kjøring
mva = delsumEksMva × maxPositiv(mvaProsent) / 100
total = delsumEksMva + mva
```

`maxPositiv` betyr at `nil`, null og negative verdier behandles som 0. Materialmengden normaliseres ikke i selve kalkulatoren, men skjemaet krever mengde over 0. Enhetspris mangler/er ikke positiv gir 0 i estimatet.

Kilder: `JobbBevis/JobbBevis/Services/PriceEstimateCalculator.swift:13`; inndatavalidering i `JobbBevis/JobbBevis/Views/JobFormView.swift:141` og `JobbBevis/JobbBevis/Views/MaterialEntryFormView.swift:126`.

Et eksisterende kjernetestscenario bekrefter: 10 t × 800 + 2 × 500 + 50 km × 5 = 9 250 eks. MVA; 25 % MVA = 2 312,50; total = 11 562,50.

Kilde: `JobbBevis/JobbBevis/Services/CoreTestSupport.swift:190`.

## Registrerte timer og kjøring

- Registrerte timer er summen av alle ikke-negative `durationMinutes`, delt på 60.
- Registrert kjøring er summen av alle ikke-negative kilometerverdier på arbeidsregistreringene.
- Arbeidsskjemaet lagrer `timer × 60 + minutter` og krever positiv total varighet.
- Kjøring på en arbeidsregistrering er valgfri, men kan ikke være negativ.

Kilder: `JobbBevis/JobbBevis/Services/PriceEstimateCalculator.swift:41`; `JobbBevis/JobbBevis/Views/WorkEntryFormView.swift:89`.

## Tilbud, ordrebekreftelse og faktura

Salgsdokumenter bygges linjevis. Hver linje beregnes slik:

```text
linjeEksMva = mengde × enhetspris
linjeMva = linjeEksMva × mvaProsent / 100
linjeTotal = linjeEksMva + linjeMva
dokumentEksMva = Σ(linjeEksMva)
dokumentMva = Σ(linjeMva)
dokumentTotal = dokumentEksMva + dokumentMva
```

Kilde: `JobbBevis/JobbBevis/Models/InvoiceRecord.swift:4`.

### Estimatgrunnlag, brukt for tilbud

- Arbeidslinje: planlagte timer × oppdragets timepris.
- Varelinjer: gyldige `PurchaseItem`-linjer, sortert på varenavn.
- Kjøringslinje: planlagte kilometer × kilometerpris.

Kilder: `JobbBevis/JobbBevis/Services/SalesDocumentService.swift:83`, `JobbBevis/JobbBevis/Services/SalesDocumentService.swift:92`, `JobbBevis/JobbBevis/Services/SalesDocumentService.swift:109`; tilbudskall i `JobbBevis/JobbBevis/Views/SalesDocumentsView.swift:147`.

### Registrert grunnlag, brukt for ordrebekreftelse og faktura

- Arbeidslinje: registrerte minutter summert og omregnet til timer × oppdragets timepris.
- Materiallinjer: prisede `MaterialEntry`-linjer, sortert på navn.
- Kjøringslinje: registrerte kilometer fra arbeidsregistreringene × kilometerpris.
- Fakturering bruker registrert grunnlag som standard. Ordrebekreftelsen kaller også standardgrunnlaget.

Kilder: `JobbBevis/JobbBevis/Services/SalesDocumentService.swift:50`, `JobbBevis/JobbBevis/Services/SalesDocumentService.swift:100`, `JobbBevis/JobbBevis/Services/SalesDocumentService.swift:165`; `JobbBevis/JobbBevis/Views/SalesDocumentsView.swift:161`.

Linjer tas bare med når mengde/tid/kilometer er større enn 0 og sats/pris er minst 0. Dokumentet avvises dersom det ikke finnes linjer eller ingen linje har positiv total.

Kilde: `JobbBevis/JobbBevis/Services/SalesDocumentService.swift:86` og `JobbBevis/JobbBevis/Services/SalesDocumentService.swift:118`.

## MVA

- Dersom firmaet er MVA-registrert, må oppdraget ha en MVA-sats. Samme sats brukes på alle dokumentlinjer.
- Dersom firmaet ikke er MVA-registrert, brukes 0 %, uavhengig av eventuell sats på oppdraget.
- Jobbskjemaets foreslåtte standardtekst er 25 %, men 25 % er ikke hardkodet som universell beregningsregel.
- Prisestimatkalkulatoren ser bare på oppdragets sats og kontrollerer ikke firmaets registreringsstatus. Salgsdokumenttjenesten gjør denne kontrollen. Dermed kan prisestimat og salgsdokument avvike hvis firmaet ikke er MVA-registrert, men oppdraget likevel har sats.

Kilder: `JobbBevis/JobbBevis/Services/SalesDocumentService.swift:74`; `JobbBevis/JobbBevis/Views/JobFormView.swift:45`; `JobbBevis/JobbBevis/Services/PriceEstimateCalculator.swift:20`.

## Avrunding og formatering

- Det er ikke funnet eksplisitt matematisk avrunding per linje, for MVA eller for dokumenttotaler.
- Beregningene utføres med Swift `Decimal` og summerer uavrundede delverdier.
- Valuta vises i NOK med nøyaktig to desimaler via formattering. Dette er en visningsregel, ikke dokumentert lagrings- eller beregningsavrunding.
- CSV-eksport bruker `NSDecimalNumber(...).stringValue` og legger ikke på eksplisitt todesimalsavrunding.

Kilder: `JobbBevis/JobbBevis/Services/PriceEstimateCalculator.swift:33`; `JobbBevis/JobbBevis/Models/InvoiceRecord.swift:12`; `JobbBevis/JobbBevis/Services/AccountingCSVExportService.swift:75`.

## Arbeidspakkebudsjetter i hovedentreprise

- `totalBudgetIncludingVAT` er summen av ikke-negative material- og arbeidsbudsjetter som begge er navngitt «inkludert MVA».
- `totalBudgetExcludingVAT` er det ikke-negative feltet `budgetExcludingVAT`.
- Det er ingen beregning mellom inkl.- og ekskl.-MVA-feltene.
- Brukergrensesnittet sier uttrykkelig at arbeidspakkebudsjetter er eks. MVA og ikke inngår i prisestimat eller faktura. Dette står i spenning med modellens to «inkludert MVA»-felter og må avklares før eventuell senere webstøtte.

Kilder: `JobbBevis/JobbBevis/Models/ProjectStructure.swift:155`; `JobbBevis/JobbBevis/Views/ProjectStructureView.swift:187` og `JobbBevis/JobbBevis/Views/ProjectStructureView.swift:201`.

## Uavklarte regler – ikke implementer uten beslutning

1. På hvilket tidspunkt, og med hvilken regel, skal beløp avrundes til øre: per linje, per MVA-sats eller bare på sluttsum?
2. Er varekatalog-, material- og innkjøpspriser alltid eks. MVA? Koden behandler dem slik i salgsdokumenter, men modellen navngir ikke prisgrunnlaget.
3. Skal et «priestimat» bruke registrerte materialer slik iOS gjør nå, eller planlagte innkjøp slik tilbudet gjør?
4. Skal ordrebekreftelsen virkelig bruke registrert grunnlag, eller burde den bruke samme estimatgrunnlag som tilbudet?
5. Skal estimat-MVA undertrykkes når firmaet ikke er MVA-registrert, slik salgsdokumentene gjør?
6. Finnes det forretningsregler for rabatt, påslag, minimumstid, timeavrunding, reisetid, bom/ferge eller andre utlegg? Ingen slike regler er funnet.
7. Hvordan skal hovedentreprisens ekskl.- og inkl.-MVA-budsjetter avstemmes? Ingen konverteringsregel er funnet.
