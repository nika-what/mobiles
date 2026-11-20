@echo off
cd /d %~dp0
echo Activating virtual environment...
call venv\Scripts\activate.bat
echo Starting server...
python main.py
pause

