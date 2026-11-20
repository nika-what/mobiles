# PowerShell script to start the FastAPI server
Set-Location $PSScriptRoot
Write-Host "Activating virtual environment..." -ForegroundColor Green
& .\venv\Scripts\Activate.ps1
Write-Host "Starting server on http://localhost:8000..." -ForegroundColor Green
python main.py







