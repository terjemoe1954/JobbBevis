#!/usr/bin/env python3
"""Run the feature checks together against the current source, using isolated data."""
from pathlib import Path
import json, plistlib, subprocess, tempfile, shutil
root=Path(__file__).resolve().parents[1]
checks=['MaterialTransferChecks','InvoiceDraftChecks','PriceSeparationChecks','ItemNumberChecks','ReportPriceChecks','ExerciseDateChecks','AccountingSelectionChecks','RegisterImportChecks']
folder=Path(tempfile.mkdtemp(prefix='JobbBevis-Release-Checks-'))
bundle=folder/'ReleaseChecks.app'/'Contents'
(bundle/'MacOS').mkdir(parents=True)
plistlib.dump({'CFBundleIdentifier':'no.jobbbevis.isolated-release-checks','CFBundleExecutable':'ReleaseChecks','CFBundleName':'ReleaseChecks','CFBundlePackageType':'APPL','CFBundleDevelopmentRegion':'en','CFBundleLocalizations':['en','nb']},(bundle/'Info.plist').open('wb'))
strings=json.loads((root/'JobbBevis/Resources/Localizable.xcstrings').read_text())['strings']
for lang in ['en','nb']:
    dest=bundle/'Resources'/(lang+'.lproj');dest.mkdir(parents=True)
    values={key:value.get('localizations',{}).get(lang,{}).get('stringUnit',{}).get('value',key) for key,value in strings.items()}
    plistlib.dump(values,(dest/'Localizable.strings').open('wb'))
source=[]
for name in checks:
    text=(root/'verification'/(name+'.swift')).read_text().replace('@main struct','struct').replace('static func main()','static func run()')
    if name=='PriceSeparationChecks':
        text=text.replace('  assert(PDFDocument(url: pdf)!.string!.contains("Fiktiv kunde"))','  assert(PDFDocument(url: pdf)!.string!.contains("Fiktiv kunde"))\n  try FileManager.default.removeItem(at: pdf)')
    source.append(text)
source.append((root/'verification/ReleaseIntegrationChecks.swift').read_text())
source.append('@main struct ReleaseChecks { @MainActor static func main() async throws {')
for name in checks:
    source.append('print("Checking '+name+'")')
    source.append(('try await ' if name=='ReportPriceChecks' else 'try ')+name+'.run()')
source.append('try ReleaseIntegrationChecks.run(); print("ALL RELEASE CHECKS PASSED") } }')
merged=folder/'ReleaseChecks.swift';merged.write_text('\n'.join(source))
sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
sources=sorted((root/'JobbBevis/Models').glob('*.swift'))
sources += [root/'JobbBevis/Config'/name for name in ['EntryFormatting.swift','AppPreferences.swift','NorwegianNumberValidator.swift']]
sources += [root/'JobbBevis/Services'/name for name in ['PriceEstimateCalculator.swift','JobDateValidation.swift','SalesDocumentService.swift','MaterialTransferService.swift','PDFReportService.swift','AccountingCSVExportService.swift','AccountingReportPDFService.swift','AccountingExportSelection.swift','BackupService.swift','ManagedFileStore.swift','PhotoFileStore.swift']]
executable=bundle/'MacOS'/'ReleaseChecks'
command=['xcrun','swiftc','-sdk',sdk,'-target','arm64-apple-ios17.0-macabi','-F',sdk+'/System/iOSSupport/System/Library/Frameworks','-I',sdk+'/System/iOSSupport/usr/include',*map(str,sources),str(merged),'-o',str(executable)]
subprocess.run(command,check=True,cwd=root)
subprocess.run([str(executable),'-AppleLanguages','(nb)'],check=True,cwd=root)
print('Isolated runner:',folder)

# Upgrade a copied fictional pre-change store; never open user data.
legacy=folder/'legacy-store';legacy.mkdir()
shutil.copy2(root/'verification/fixtures/legacy-pre-change.sqlite',legacy/'JobbBevis.store')
shutil.copy2(root/'verification/fixtures/legacy-snapshot.bin',legacy/'original-snapshot.bin')
migration=folder/'MigrationChecks'
subprocess.run(['xcrun','swiftc','-module-name','JobbBevisMigrationFixture',*map(str,sorted((root/'JobbBevis/Models').glob('*.swift'))),str(root/'verification/CombinedMigrationChecks.swift'),'-o',str(migration)],check=True,cwd=root)
subprocess.run([str(migration),str(legacy)],check=True,cwd=root)
print('ALL FEATURE AND ORIGINAL-SCHEMA MIGRATION CHECKS PASSED')
