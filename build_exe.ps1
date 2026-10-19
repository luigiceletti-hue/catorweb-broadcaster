# Crea l'edizione distribuibile di Catorweb Broadcaster:
#   build\pacchetto\CatorwebBroadcaster\   cartella pronta (CatorwebBroadcaster.exe + app\ + liquidsoap\)
#   build\Setup_CatorwebBroadcaster.exe   installatore (se Inno Setup 6 e' installato)
# Uso:  powershell -ExecutionPolicy Bypass -File build_exe.ps1
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$dist = Join-Path $root "build\pacchetto\CatorwebBroadcaster"

Write-Host "0/3  Pagine in inglese (app\i18n\*.json)..."
# I testi nuovi finiscono nei dizionari con valore "": vanno tradotti a mano,
# finche' non lo sono restano in italiano nella versione inglese.
$tool = Join-Path $root "tools\i18n_tool.py"
$app  = Join-Path $root "app"
foreach ($p in @(@("catorweb_radio", "en"), @("impostazioni", "impostazioni_en"))) {
    py -3 $tool extract (Join-Path $app "$($p[0]).html") (Join-Path $app "i18n\$($p[1]).json")
    py -3 $tool apply (Join-Path $app "$($p[0]).html") (Join-Path $app "i18n\$($p[1]).json") (Join-Path $app "$($p[0]).en.html")
}
py -3 (Join-Path $root "tools\i18n_py.py") extract (Join-Path $app "radio_broadcaster_server.py") (Join-Path $app "i18n\server_en.json")

Write-Host "1/3  PyInstaller..."
Remove-Item -Recurse -Force (Join-Path $root "app\__pycache__") -ErrorAction SilentlyContinue
Push-Location $root
py -3 -m PyInstaller --noconfirm --clean --onedir --console --name CatorwebBroadcaster `
   --paths app --hidden-import mutagen --hidden-import edition_config `
   --distpath build\pacchetto --workpath build\work --specpath build `
   app\radio_broadcaster_server.py
if ($LASTEXITCODE -ne 0) { Pop-Location; throw "PyInstaller non riuscito" }
Pop-Location

Write-Host "2/3  Copia interfaccia e Liquidsoap..."
New-Item -ItemType Directory -Force (Join-Path $dist "app") | Out-Null
Copy-Item (Join-Path $root "app\catorweb_radio.html"), (Join-Path $root "app\impostazioni.html"), `
          (Join-Path $root "app\catorweb_radio.en.html"), (Join-Path $root "app\impostazioni.en.html"), `
          (Join-Path $root "app\help.html"), (Join-Path $root "app\help.en.html"), `
          (Join-Path $root "app\cwpc_edizione.liq") (Join-Path $dist "app")
New-Item -ItemType Directory -Force (Join-Path $dist "app\i18n") | Out-Null
Copy-Item (Join-Path $root "app\i18n\server_en.json") (Join-Path $dist "app\i18n")
# Jingle di esempio: al primo avvio finiscono nella categoria "Jingle" (vedi _seed_demo_jingles)
New-Item -ItemType Directory -Force (Join-Path $dist "app\jingle") | Out-Null
Copy-Item (Join-Path $root "app\jingle\*.mp3") (Join-Path $dist "app\jingle")
Copy-Item (Join-Path $root "README.txt") $dist
robocopy (Join-Path $root "liquidsoap") (Join-Path $dist "liquidsoap") /E /XF test.liq /NFL /NDL /NJH /NJS | Out-Null
Copy-Item (Join-Path $root "LEGGIMI.txt") $dist
# Licenze dei componenti (Liquidsoap, mutagen, Python, ...): vanno distribuite col programma
New-Item -ItemType Directory -Force (Join-Path $dist "licenze") | Out-Null
Copy-Item (Join-Path $root "licenze\*") (Join-Path $dist "licenze")

Write-Host "3/3  Installatore..."
$iscc = @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
          "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($iscc) {
    & $iscc /Q (Join-Path $root "installer.iss")
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup non riuscito" }
    Write-Host "Fatto: build\Setup_CatorwebBroadcaster.exe"
} else {
    Write-Host "Inno Setup 6 non trovato: creata solo la cartella $dist"
}

