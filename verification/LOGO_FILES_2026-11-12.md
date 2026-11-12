# Logo fra Filer – neste build

Implementert i SettingsView.swift med norske og engelske tekster. Velg/bytt logo gir valgene Bilder og Filer. Filvelgeren tillater ett bilde og bruker sikkerhetsavgrenset tilgang mens filen leses. Bildet kopieres til eksisterende lokal logolagring. Uleselige bilder avvises; eksisterende logo beholdes dersom import eller lagring feiler. Ingen endring i datamodell eller backupformat.

Kontroll: Debug-build med Xcode fullførte uten feil. På eksisterende iPad Pro 13-inch (M5), UDID 11D4D75C-A33C-49F1-AE17-EB2CBC53AA44, åpnet Codex Innstillinger → Velg logo → Velg fra Filer. En PNG-testlogo (appens eget ikon) ble valgt fra On My iPad. Logoen ble vist i firmaprofilen og handlingen skiftet til Bytt logo / Fjern logo. Eksisterende eksempeloppdrag og firmadata ble bevart. Testlogoen står tilgjengelig i simulatoren.

App Store Connect, innsendt build 11, arkivet og Pluss-produktet er ikke endret. Endringen ligger kun i kildekoden og lokal Debug-build til neste utgivelse.
