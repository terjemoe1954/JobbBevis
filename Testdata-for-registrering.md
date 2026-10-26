# Testdata for JobbBevis

Alt nedenfor er oppdiktet og laget kun for testing. Organisasjonsnumrene har gyldig kontrollsiffer, men skal ikke brukes som virkelige foretaksopplysninger.

## 1. Kunder

| ID | Kunde | Type | Organisasjonsnummer | Adresse | Poststed | Telefon | E-post |
|---|---|---|---|---|---|---|---|
| K1 | Nora Vik | Privatkunde | – | Granstubben 14 | 1362 Hosle | 900 11 201 | nora.vik@example.no |
| K2 | Solsiden Borettslag | Bedrift | 123 456 785 | Solsiden 2 | 0654 Oslo | 900 11 202 | styret@solsiden.example.no |
| K3 | Fjord & Fjell Eiendom AS | Bedrift | 987 654 325 | Havnegata 18 | 3040 Drammen | 900 11 203 | drift@fjordfjell.example.no |
| K4 | Lars Hauge | Privatkunde | – | Furulia 7 | 1482 Nittedal | 900 11 204 | lars.hauge@example.no |

## 2. Vareregister

Prisene er testpriser ekskl. mva.

| Varenr. | Fag | Varenavn | Enhet | Pris ekskl. mva |
|---|---|---|---|---:|
| EL-101 | Elektriker | Automatsikring 16 A | stk. | 189,00 kr |
| EL-102 | Elektriker | Installasjonskabel 3G1,5 | meter | 24,90 kr |
| EL-103 | Elektriker | Dobbel stikkontakt, innfelt | stk. | 149,00 kr |
| EL-104 | Elektriker | LED-plafond 18 W | stk. | 649,00 kr |
| SN-201 | Snekker | Konstruksjonsvirke 48 × 98 mm | meter | 42,90 kr |
| SN-202 | Snekker | Terrassebord 28 × 120 mm | meter | 34,90 kr |
| SN-203 | Snekker | Terrasseskrue 5 × 80 mm, eske | eske | 179,00 kr |
| SN-204 | Snekker | Innerdør 80 × 210 cm, hvit | stk. | 1 890,00 kr |
| RØ-301 | Rørlegger | Servantbatteri, ettgreps | stk. | 1 290,00 kr |
| RØ-302 | Rørlegger | PEX-rør 15 mm | meter | 32,00 kr |
| RØ-303 | Rørlegger | Kuleventil 15 mm | stk. | 249,00 kr |
| RØ-304 | Rørlegger | Varmtvannsbereder 120 liter | stk. | 7 990,00 kr |

## 3. Oppdrag

| Oppdrag | Kunde | Fag | Tittel og arbeidssted | Dato | Status som skal testes | Timer | Varer |
|---|---|---|---|---|---|---:|---|
| O-1001 | K1 | Elektriker | Bytte sikringsskap, Granstubben 14 | 05.10.2026 | Ferdig – faktura godkjent | 8,5 | 8 × EL-101, 12 m EL-102, 2 × EL-103 |
| O-1002 | K2 | Elektriker | Ny belysning i fellesgang, Solsiden 2 | 12.–14.10.2026 | Pågår – ikke fakturerbar ennå | 11,0 | 8 × EL-104, 35 m EL-102 |
| O-1003 | K3 | Snekker | Skifte innerdør og listverk, Havnegata 18 | 08.–09.10.2026 | Ferdig – fakturautkast kan endres | 10,0 | 1 × SN-204, 14 m SN-201 |
| O-1004 | K4 | Snekker | Nye trappetrinn og rekkverk på terrasse, Furulia 7 | 02.11.2026 | Planlagt – skriv ordrebekreftelse | 0,0 | 28 m SN-201, 32 m SN-202, 2 × SN-203 |
| O-1005 | K1 | Rørlegger | Stoppe lekkasje og skifte servantbatteri, Granstubben 14 | 16.10.2026 | Ferdig – faktura godkjent og deretter kreditert | 3,5 | 1 × RØ-301, 2 m RØ-302, 2 × RØ-303 |
| O-1006 | K2 | Rørlegger | Skifte varmtvannsbereder, Solsiden 2 | 19.10.2026 | Ferdig – fakturautkast slettes og lages på nytt | 6,0 | 1 × RØ-304, 4 m RØ-302, 3 × RØ-303 |

## 4. Bilder

Bruk samme nummer som på bildearket **Testbilder-01-20.png**.

| Bilde | Oppdrag | Kategori | Bildetekst som registreres |
|---:|---|---|---|
| 01 | O-1001 | Før | Gammelt sikringsskap før utskifting |
| 02 | O-1001 | Underveis | Arbeid i sikringsskap etter frakobling |
| 03 | O-1001 | Etter | Nytt sikringsskap ferdig montert |
| 04 | O-1002 | Før | Mørk fellesgang med gammel belysning |
| 05 | O-1002 | Underveis | Trekking av kabel til nye taklamper |
| 06 | O-1002 | Underveis | LED-lamper montert før funksjonstest |
| 07 | O-1002 | Etter | Fellesgangen med ferdig belysning |
| 08 | O-1003 | Før | Slitt innerdør og skadet listverk |
| 09 | O-1003 | Underveis | Gammel dørkarm demonteres |
| 10 | O-1003 | Underveis | Nytt listverk monteres |
| 11 | O-1003 | Etter | Ny innerdør og ferdig listverk |
| 12 | O-1004 | Før | Slitte trinn og rekkverk på terrasse |
| 13 | O-1004 | Før | Oppmåling og materialer klargjort |
| 14 | O-1005 | Før | Lekkasje ved gammelt servantbatteri |
| 15 | O-1005 | Underveis | Rørkoblinger under servant skiftes |
| 16 | O-1005 | Etter | Nytt servantbatteri, kontrollert for lekkasje |
| 17 | O-1006 | Før | Gammel varmtvannsbereder før utskifting |
| 18 | O-1006 | Underveis | Bereder frakoblet og ventiler kontrollert |
| 19 | O-1006 | Underveis | Ny bereder monteres og kobles til |
| 20 | O-1006 | Etter | Ny bereder ferdig montert med lekkasjesikring |

## 5. Anbefalt registreringsrekkefølge

1. Registrer de fire kundene.
2. Registrer de tolv varene.
3. Opprett de seks oppdragene og legg til timer og varer.
4. Legg inn bildene fra arket på riktig oppdrag med kategori og bildetekst.
5. Skriv ut ordrebekreftelse for O-1004.
6. La O-1002 stå som pågående.
7. Lag fakturautkast for O-1003, endre én varelinje, og behold utkastet.
8. Lag fakturautkast for O-1006, slett utkastet, lag det på nytt og godkjenn fakturaen.
9. Godkjenn fakturaen for O-1001 og kontroller at neste utskrift heter «Fakturakopi».
10. Godkjenn fakturaen for O-1005, opprett en kreditnota, og kontroller at både faktura og kreditnota ligger i oversikten.
11. Forsøk å slette O-1001 og kontroller at appen krever en tydelig bekreftelse fordi oppdraget er fakturert.

