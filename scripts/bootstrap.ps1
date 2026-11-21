# One-time setup (Windows). From the repo root:
#   powershell -ExecutionPolicy Bypass -File scripts/bootstrap.ps1
$ErrorActionPreference = "Stop"
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host "Flutter not found. See docs/setup/machine-setup.md"; exit 1
}
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $Root

function New-Platform($dir, $platform, $project) {
  Write-Host "==> flutter create ($platform) in $dir"
  $files = @("pubspec.yaml", "analysis_options.yaml", "README.md", "lib/main.dart", "test/widget_test.dart")
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
  foreach ($f in $files) {
    $src = Join-Path $dir $f
    if (Test-Path $src) {
      $dst = Join-Path $tmp $f
      New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
      Copy-Item $src $dst
    }
  }
  Push-Location $dir
  flutter create --platforms=$platform --org com.sapati --project-name $project .
  Pop-Location
  foreach ($f in $files) {
    $bak = Join-Path $tmp $f
    if (Test-Path $bak) { Copy-Item $bak (Join-Path $dir $f) -Force }
  }
  Remove-Item -Recurse -Force $tmp
}

New-Platform "apps/mobile" "android" "rental"
New-Platform "apps/admin_web" "web" "rental_admin"

$manifest = "apps/mobile/android/app/src/main/AndroidManifest.xml"
if (Test-Path $manifest) {
  (Get-Content $manifest -Raw) -replace 'android:label="[^"]*"', 'android:label="Rental"' | Set-Content $manifest -NoNewline
}
$index = "apps/admin_web/web/index.html"
if (Test-Path $index) {
  (Get-Content $index -Raw) -replace '<title>[^<]*</title>', '<title>Rental Admin</title>' | Set-Content $index -NoNewline
}

Write-Host "==> flutter pub get"
flutter pub get
Write-Host "==> dart format"
dart format apps packages
Write-Host "Done. Check applicationId is com.sapati.rental in apps/mobile/android/app/build.gradle*"
Write-Host "Next: git add . ; git commit -m 'chore: platform folders' ; git push"
