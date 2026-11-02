# Link the kits into addons\ (directory junctions: no admin rights or
# Developer Mode needed) and fetch the audio kit's native core.
#   .\tools\setup.ps1                        # kits from the vendor\ submodules
#   .\tools\setup.ps1 -KitsDir C:\dev        # kits from sibling checkouts
param([string]$KitsDir = "")
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if ($KitsDir -ne "") {
    $mk = Join-Path $KitsDir "godot-motion-kit"
    $ak = Join-Path $KitsDir "godot-audio-kit"
} else {
    git submodule update --init --depth 1
    $mk = Join-Path $PWD "vendor\godot-motion-kit"
    $ak = Join-Path $PWD "vendor\godot-audio-kit"
}

New-Item -ItemType Directory -Force -Path addons | Out-Null
foreach ($pair in @(@("motion_kit", $mk), @("audio_kit", $ak))) {
    $name = $pair[0]
    $src = (Resolve-Path (Join-Path $pair[1] "addons\$name")).Path
    $dst = Join-Path $PWD "addons\$name"
    if (Test-Path $dst) { (Get-Item $dst).Delete() }   # removes the junction, not its target
    New-Item -ItemType Junction -Path $dst -Target $src | Out-Null
    Write-Host "addons\$name -> $src"
}

# The audio kit's native core (LIVE sound): CI builds it for Windows.
$bin = Join-Path $ak "addons\audio_kit\native\bin"
if (Test-Path (Join-Path $bin "libaknative.windows.template_debug.x86_64.dll")) {
    Write-Host "native core: present"
} elseif (Get-Command gh -ErrorAction SilentlyContinue) {
    $run = gh run list -R csmallfield/godot-audio-kit --workflow native.yml --branch main --status success -L 1 --json databaseId --jq ".[0].databaseId"
    New-Item -ItemType Directory -Force -Path $bin | Out-Null
    gh run download $run -R csmallfield/godot-audio-kit -n audio-kit-native -D $bin
    Write-Host "native core: from CI run $run"
} else {
    Write-Host "native core: missing. Install gh (winget install GitHub.cli) and rerun, or download the"
    Write-Host "audio-kit-native artifact from the audio kit's Actions page and unzip it into $bin"
}
