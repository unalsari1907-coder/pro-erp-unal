@echo off
title PRO ERP - Bilgisayarda Calistir
cd /d "%~dp0"

where flutter >nul 2>nul
if errorlevel 1 goto flutter_yok

echo Bagimliliklar hazirlaniyor...
call flutter pub get
if errorlevel 1 goto hata

echo PRO ERP Chrome uzerinde aciliyor...
call flutter run -d chrome
if errorlevel 1 goto hata
exit /b 0

:flutter_yok
echo Flutter bulunamadi. Flutter PATH ayarini kontrol edin.
pause
exit /b 1

:hata
echo.
echo Islem tamamlanamadi. Yukaridaki hata mesajini paylasin.
pause
exit /b 1
