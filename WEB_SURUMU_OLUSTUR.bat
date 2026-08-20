@echo off
title PRO ERP 2.5.13 - Mobil Web Release
cd /d "%~dp0"

where flutter >nul 2>nul
if errorlevel 1 goto flutter_yok

echo 1/4 Temizlik...
call flutter clean
if errorlevel 1 goto hata

echo 2/4 Paketler...
call flutter pub get
if errorlevel 1 goto hata

echo 3/4 Kod analizi...
call flutter analyze --no-fatal-warnings --no-fatal-infos
if errorlevel 1 goto hata

echo 4/4 Production web build...
call flutter build web --release --no-wasm-dry-run --no-tree-shake-icons
if errorlevel 1 goto hata

echo.
echo ==========================================================
echo TAMAMLANDI
echo Cloudflare / web sunucusuna yuklenecek klasor:
echo %CD%\build\web
echo ==========================================================
pause
exit /b 0

:flutter_yok
echo Flutter bulunamadi. Flutter PATH ayarini kontrol edin.
pause
exit /b 1

:hata
echo.
echo Build durduruldu. Yukaridaki hatayi duzeltmeden yayin yapmayin.
pause
exit /b 1
