# Delvis materialoverføring

Innkjøpslinjen beholder planlagt mengde og pris. Trykk mengdeikonet for å registrere brukt mengde. Listen viser brukt og gjenstående. Overforbruk er tillatt med varsel.

Manuelt registrerte materialer kan kobles til en innkjøpslinje i materialskjemaet. Mengde og pris beholdes. Redigering og sletting oppdaterer oversikten. Gamle en-til-en-koblinger støttes. Ny valgfri kobling følger med sikkerhetskopier.

Kontrollert: Xcode-bygg og isolert SwiftData-kontroll i minnet av delmengder, gjentatt innsending, utdatert skjema, ugyldig mengde, redigering, kobling/frakobling, overforbruk, sletting og eldre kobling. Kontrollfilen kan kompileres sammen med Models/*.swift og Services/MaterialTransferService.swift.

Ikke kjørt mot brukerens eksisterende database. Ta sikkerhetskopi før første kjøring av ny build. Endringen er ikke installert eller lastet opp til TestFlight.
