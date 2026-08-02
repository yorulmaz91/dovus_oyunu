@echo off
REM ============================================================
REM  Yerel test sunucusu - build\web klasorunu 8000 portunda yayinlar.
REM
REM  Bilgisayardan  : http://localhost:8000/index.html
REM  Telefondan     : ayni Wi-Fi agindayken http://<bilgisayarin-IP>:8000
REM                   (IP'yi ogrenmek icin: ipconfig)
REM
REM  Guvenlik duvari sorarsa "Ozel aglar" icin izin ver.
REM  Durdurmak icin bu pencerede Ctrl+C.
REM
REM  NOT: Oyunu dosyaya cift tiklayarak (file://) acamazsin - tarayici
REM  .wasm dosyasini oradan yuklemez. Mutlaka bir sunucu gerekir.
REM ============================================================
title Dovus Oyunu - yerel sunucu (8000)

if not exist "%~dp0..\build\web\index.html" (
  echo HATA: build\web\index.html yok.
  echo Once web derlemesini yap - tools\yayinla.bat calistirabilirsin
  echo ya da su komutu ver:
  echo   "C:\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --export-release "Web" build/web/index.html
  pause
  exit /b 1
)

echo Adres: http://localhost:8000/index.html
echo Durdurmak icin Ctrl+C
echo.
cd /d "%~dp0..\build\web" && (python -m http.server 8000 || py -m http.server 8000)
pause
