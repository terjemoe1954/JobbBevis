# Periode- og fakturavalg ved regnskapseksport

Eksportskjermen kan avgrenses etter fakturadato, med inkluderende fra- og til-dato. Avgrensningen bruker enhetens lokale kalenderdager, samme dato som vises i fakturalisten og PDF-en. Hele siste dagen tas med; neste dags grense beregnes i kalenderen, ikke med et fast antall sekunder. Ugyldig periode gir varsel og ingen eksport.

Fakturaer kan velges enkeltvis, alle i visningen eller ingen. Fakturaer utenfor perioden tas aldri med, selv om de tidligere var valgt. Fravalg beholdes når perioden endres; nye fakturaer er valgt som standard når de kommer inn i visningen. Øvelsesfakturaer holdes utenfor både listen og eksporttjenestene.

Kontrollfelt viser antall fakturaer i visningen, valgte fakturaer, fakturalinjer, sum ekskl. MVA, MVA og total. Uleselig valgt kopi stopper eksport, men kan velges bort. Tomt utvalg stopper eksport. CSV og PDF mottar samme utvalg. Kontrollsummen teller hver faktura bare én gang.

CSV har fortsatt de samme 24 kolonnene, én rad per fakturalinje, UTF-8 BOM, anførselstegn rundt feltene, CRLF og uendret desimaltallformat. invoice_subtotal, invoice_vat og invoice_total gjentas per linje og skal regnes én gang per invoice_number; linjefeltene kan summeres. Skjermen forklarer dette. Datokolonnene beholder yyyy-MM-dd-format, men bruker nå lokale kalenderdatoer, så fakturaer rundt midnatt ikke får en annen dato enn skjerm/PDF. Tidligere eksportfiler endres ikke.

PDF-overskriften fikk tilstrekkelig høyde for sin skriftstørrelse. Ingen lagringsmodell eller fakturakopi endres. Eksport er en filoperasjon og bekrefter ikke import eller bokføring. Kreditnotaer er fortsatt ikke egne rader i dette eksisterende CSV-formatet; konkret regnskapsimport må avklares separat.

Kontrollert: Xcode-bygg, isolert test med grenseverdier ved lokal midnatt, sommertid (23-timers dag), enkeltvalg, ugyldig periode, tomt utvalg, duplikate ID-er, TEST-utestenging og uleselig kopi. To valgte fakturaer ga tre linjer, 2 630,00 kr ekskl. MVA, 657,50 kr MVA og 3 287,50 kr total. CSV lest med standard CSV-parser; kolonner, datoer, komma/anførselstegn, linjesummer og sum per unik faktura avstemt. PDF viser de samme to fakturaene og summene; rendret og visuelt kontrollert. Ingen brukerdata åpnet. Ikke installert eller sendt til TestFlight.
