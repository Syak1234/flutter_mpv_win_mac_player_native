$ErrorActionPreference = 'Stop'

$dll1 = Join-Path $PSScriptRoot '..\packages\mpv_native_texture\windows\third_party\mpv\bin\mpv-2.dll'

if (Test-Path $dll1) {
  Write-Host "OK: Found mpv-2.dll at $dll1"
  exit 0
}

Write-Host "Missing mpv-2.dll. Put it here:" -ForegroundColor Yellow
Write-Host "  $dll1" -ForegroundColor Yellow
Write-Host "Or copy it next to your built Runner.exe (Release/Debug)." -ForegroundColor Yellow
exit 1
