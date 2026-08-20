@echo off
title PRO ERP 2.5.11 - Telefonda Release Test
cd /d "%~dp0"

where flutter >nul 2>nul
if errorlevel 1 goto flutter_yok

echo Bagimliliklar hazirlaniyor...
call flutter pub get
if errorlevel 1 goto hata

echo.
echo Kod kontrol ediliyor...
call flutter analyze
if errorlevel 1 goto hata

echo.
echo ==========================================================
echo PRO ERP TELEFON TESTI - RELEASE MODU
echo ==========================================================
echo Bilgisayar ve telefon ayni Wi-Fi agina bagli olmalidir.
echo Wi-Fi kartiniza ait IPv4 adresini kullanin:
ipconfig | findstr /i "IPv4"
echo.
echo Telefonda Chrome veya Safari acip su bicimde yazin:
echo http://BILGISAYAR_IP_ADRESI:8080
echo Ornek: http://192.168.1.25:8080
echo.
echo NOT: Release modu debug modundan belirgin sekilde daha hizlidir.
echo Bu pencere acik kaldigi surece telefon baglantisi calisir.
echo Windows Guvenlik Duvari sorarsa ozel ag icin erisime izin verin.
echo.

call flutter run --release -d web-server --web-hostname 0.0.0.0 --web-port 8080
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
