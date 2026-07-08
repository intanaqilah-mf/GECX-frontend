# ACN Banking App - Startup Script

Write-Host "--- 1. Checking Google Cloud Authentication ---" -ForegroundColor Cyan
# Set the project explicitly to match your screenshot
gcloud config set project emvnzir-canada-song
gcloud auth application-default login

Write-Host "`n--- 2. Clearing old credential paths ---" -ForegroundColor Cyan
$env:GOOGLE_APPLICATION_CREDENTIALS=""
$env:GOOGLE_CLOUD_PROJECT="emvnzir-canada-song"

Write-Host "`n--- 3. Starting FastAPI Backend in a new window ---" -ForegroundColor Cyan
# Starts the backend in a separate window so you can see logs
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd lib/backend; python -m uvicorn app.main:app --reload"

Write-Host "`n--- 4. Starting Flutter Frontend (Edge) ---" -ForegroundColor Cyan
# Runs the flutter app on Edge
flutter run -d edge
