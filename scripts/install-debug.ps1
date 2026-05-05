$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $projectRoot '.env'

if (-not (Test-Path -LiteralPath $envFile)) {
    throw "Missing .env file. Copy .env.example to .env and fill in local API keys."
}

Push-Location $projectRoot
try {
    flutter build apk --debug --dart-define-from-file=.env
    flutter install --debug --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk
} finally {
    Pop-Location
}
