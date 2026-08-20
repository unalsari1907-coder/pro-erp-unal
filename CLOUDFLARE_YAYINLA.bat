@echo off
title PRO ERP 2.5.13 - Cloudflare Pages Yayin
cd /d "%~dp0"

echo Release build hazirlaniyor...
call "%~dp0WEB_SURUMU_OLUSTUR.bat"
if errorlevel 1 goto hata

if not exist "build\web\index.html" (
  echo build\web\index.html bulunamadi. Yayin durduruldu.
  goto hata
)

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

echo pro-erp-unal Pages projesine production yayini basliyor...
call npx wrangler pages deploy build\web --project-name=pro-erp-unal --branch=main
if errorlevel 1 goto hata

echo.
echo Son dagitimlar:
call npx wrangler pages deployment list --project-name=pro-erp-unal

echo.
echo ==========================================================
echo YAYIN TAMAMLANDI
echo https://pro-erp-unal.pages.dev
echo ==========================================================
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
echo Yayin durduruldu. Yukaridaki hatayi duzeltmeden tekrar denemeyin.
pause
exit /b 1
