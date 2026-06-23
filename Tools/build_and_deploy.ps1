# build_and_deploy.ps1
# Posiziona questo file nella cartella Tools/ del progetto

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$ProjectRoot = Resolve-Path "$ScriptDir\.."
$CppExtensionsDir = "$ProjectRoot\cpp_extensions"
$SourceDllDir = "$CppExtensionsDir\project\bin\windows"
$DestDir = "$CppExtensionsDir\bin"
$FinalDllName = "diprail_railgen.dll"
$DestPath = Join-Path $DestDir $FinalDllName

Write-Host "=== Compilazione modulo C++ ===" -ForegroundColor Cyan

# 0. Controlla se la DLL di destinazione è in uso
if (Test-Path $DestPath) {
    try {
        # Prova ad aprire il file in scrittura per verificare se è bloccato
        $stream = [System.IO.File]::Open($DestPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $stream.Close()
    } catch {
        Write-Host "ERRORE: $FinalDllName è attualmente in uso. Chiudi Godot e riprova." -ForegroundColor Red
        pause
        exit 1
    }
    # Se non è bloccato, elimina il vecchio file
    Remove-Item $DestPath -Force
}

# 1. Compila
Write-Host "[1/3] Esecuzione SCons in $CppExtensionsDir..." -ForegroundColor Yellow
Push-Location $CppExtensionsDir
try {
    scons platform=windows target=template_release
    if ($LASTEXITCODE -ne 0) { throw "Compilazione fallita" }
} finally {
    Pop-Location
}

# 2. Trova la DLL generata
$dll = Get-ChildItem "$SourceDllDir\*.dll" | Select-Object -First 1
if (-not $dll) { throw "DLL non trovata in $SourceDllDir" }
Write-Host "[2/3] DLL trovata: $($dll.Name)" -ForegroundColor Green

# 3. Copia e rinomina
New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
Copy-Item -Path $dll.FullName -Destination $DestPath -Force
Write-Host "[3/3] DLL copiata in: $DestPath" -ForegroundColor Green

# 4. Pulisce file temporanei
Get-ChildItem "$SourceDllDir\*.exp","$SourceDllDir\*.lib","$SourceDllDir\*.pdb" -ErrorAction SilentlyContinue | Remove-Item -Force

Write-Host "=== Completato ===" -ForegroundColor Cyan
pause