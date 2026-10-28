# HandyMe – Hvasser versjon 2

Fiktivt scenario. HandyMe er hovedentreprenør; Arne Elliassen er privatkunde. Prosjekt HM-2026-001 har fire fag, fem prosjektparter og åtte arbeidspakker. Alle beløp i CSV og Excel er **eks. mva.** med mindre kolonnen sier noe annet.

## Økonomi
Arbeidspakker: 1 108 000 kr eks. mva. (1 385 000 kr inkl.). Reserve 15 %: 166 200 kr eks. mva. Samlet tilbudsramme: **1 274 200 kr eks. mva. / 1 592 750 kr inkl. mva.** Reise og overnatting er ikke inkludert og må avtales. Varelisten er et utvalg for å teste pakningslogikk, **ikke** komplett materialkalkyle; ikke legg vareregister/handleliste oppå arbeidspakkebudsjettet ved summering.

## Viktig for import
Codex må lese ProjectStructure.swift og ProjectStructureView.swift og mappe CSV-feltene mot faktiske modeller. CSV-filene er et *utvekslingsformat*, ikke en påstand om at appen har CSV-import. Importen skal være idempotent, bare legge inn DEMO-data, aldri registrere planlagte timer som utført eller utkast som godkjent. Behold ID-koblingene. Ikke overskriv virkelige data. Import av bilder krever særskilt filhåndtering.

## Foreslått testrekkefølge
1. Kunde og hovedprosjekt (Hovedentreprise). 2. Fagområder. 3. Prosjektparter. 4. Arbeidspakker. 5. Varer, leverandører og pakninger. 6. Handleliste. 7. Timer og reisebudsjett. 8. Bilder. 9. Anbudsutkast. 10. Ordrebekreftelse som ikke-godkjent utkast. 11. Backup/gjenoppretting og duplikatkontroll.

## Begrensninger
Testadresse er ikke bekreftet eiendom. Alle leverandører og priser er fiktive. Elektroarbeid må utføres og dokumenteres av kvalifisert registrert virksomhet. Eksisterende hytte må befares, og tillatelser må avklares.
