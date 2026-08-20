@echo off
title PRO ERP - Cloudflare Kontrol
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 goto node_yok

if not exist "node_modules\wrangler\package.json" (
  echo Wrangler hazirlaniyor...
  call npm install
  if errorlevel 1 goto hata
)

echo Cloudflare oturumu kontrol ediliyor...
call npx wrangler whoami
if errorlevel 1 goto giris_yok

echo.
echo pro-erp-unal Pages dagitimlari:
call npx wrangler pages deployment list --project-name=pro-erp-unal
if errorlevel 1 goto hata

echo.
echo Cloudflare kontrolu tamamlandi.
pause
exit /b 0

:giris_yok
echo.
echo Cloudflare girisi gerekli. Bir kez su komutu calistirin:
echo npx wrangler login
pause
exit /b 1

:node_yok
echo Node.js bulunamadi. Node.js LTS kurulumunu kontrol edin.
pause
exit /b 1

:hata
echo.
echo Cloudflare kontrolu tamamlanamadi. Yukaridaki hatayi duzeltin.
pause
exit /b 1
