# Builds a RELEASE APK with the Gemini API key (from env.json) compiled in.
#
# Use THIS instead of Android Studio's "Build > Flutter > Build APK", which does
# NOT pass dart-defines and produces an APK with an empty key.
#
# Usage (from the project root):
#   ./build_release.ps1
#
# Output: build/app/outputs/flutter-apk/app-release.apk

if (-not (Test-Path "env.json")) {
    Write-Host "ERROR: env.json not found. Create it from env.example.json and add your GEMINI_API_KEY." -ForegroundColor Red
    exit 1
}

Write-Host "Building release APK with key from env.json..." -ForegroundColor Cyan
flutter build apk --release --dart-define-from-file=env.json

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nDone. Install this file on your phone:" -ForegroundColor Green
    Write-Host "  build\app\outputs\flutter-apk\app-release.apk"
}
