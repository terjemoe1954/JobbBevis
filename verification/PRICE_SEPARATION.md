# Tilbud og registrert forbruk

Jobboversikten viser Tilbudsgrunnlag (planlagt) fra estimerte timer/kjøring og innkjøpslisten, og Registrert hittil fra faktiske timer/kjøring og materialregistreringer. Eget arbeid vises separat fra materialer og innkjøpte tjenester. MVA følger firmaprofilens registreringsstatus. Eksisterende rapportberegning er foreløpig beholdt og skal gjennomgås i rapportarbeidet.

Innkjøpslistens priser brukes allerede i kundens anbud og videreføres ved materialoverføring; tekstene sier nå dette tydelig. Ingen separat kostpris- eller påslagsmodell er innført.

Lag tilbud, kontroller PDF, og registrer kundens aksept når kunden faktisk har akseptert den. Bekreftelsen viser kunde og beløp. Den sist forhåndsviste tilbudskopien lagres med registreringsdato, og kan åpnes senere. Kopien overskrives ikke av nye priser, kundeendringer eller forbruk. Gamle tilbud aksepteres ikke automatisk. Fakturering bruker fortsatt registrert grunnlag, og endres ikke til fastpris automatisk.

Akseptert kopi er to valgfrie lagringsfelt som følger JSON-sikkerhetskopien; eldre sikkerhetskopier uten feltene støttes. Akseptert kopi og dato må begge være gyldige ved import.

Kontrollert: Xcode-bygg, isolerte beregningskontroller mot salgsdokumentene, 274 812,50 kr tilbud og 8 162,50 kr registrert etter 8 timer og 2 kg sparkel, firma uten MVA, uforanderlig akseptert kopi, avvist dobbel aksept, eksport og innlesing av eldre sikkerhetskopier. Separat gammel testdatabase oppgradert med nye felt og bevart jobb/kunde. Brukerens database er ikke åpnet. Ikke installert eller sendt til TestFlight.
