@echo off
setlocal
REM ============================================================
REM  Dovus Oyunu - web derlemesini GitHub Pages'e yayinlar.
REM
REM  Kaynak kod "main" dalinda kalir. Bu betik YALNIZ build\web
REM  klasorunu ayni deponun "gh-pages" dalina zorla iter.
REM  Ikinci bir depo YOK.
REM
REM  Yayin adresi: https://yorulmaz91.github.io/dovus_oyunu/
REM
REM  ONEMLI: Derleme "iş parcaciksiz" (thread_support=false) yapilir.
REM  GitHub Pages COOP/COEP basligi gonderemez; is parcacikli derleme
REM  o basliklari ister ve Pages'te ACILMAZ. Ayari degistirme.
REM ============================================================

set "GODOT=C:\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
set "PROJE=%~dp0.."
set "CIKTI=%PROJE%\build\web"
set "ORIGIN=https://github.com/yorulmaz91/dovus_oyunu"

echo ============================================
echo  [1/3] Web derlemesi tazeleniyor...
echo ============================================
if not exist "%GODOT%" goto :hata_godot

REM build klasoru projenin ICINDE oldugu icin Godot onu tarar, cikti
REM PNG'lerini kendi kaynagi sanip ICE AKTARIR ve bir sonraki pakete
REM koyar - her yayinda pck buyur. .gdignore taramayi kapatir.
if not exist "%PROJE%\build" mkdir "%PROJE%\build"
type nul > "%PROJE%\build\.gdignore"

REM Onceki derlemeden kalan dosya yeni yayina sizmasin.
if exist "%CIKTI%" rmdir /s /q "%CIKTI%"
mkdir "%CIKTI%"

"%GODOT%" --headless --path "%PROJE%" --export-release "Web" "%CIKTI%\index.html"
if errorlevel 1 goto :hata_export
if not exist "%CIKTI%\index.html" goto :hata_export
if not exist "%CIKTI%\index.wasm" goto :hata_export

echo.
echo ============================================
echo  [2/3] .nojekyll ekleniyor...
echo ============================================
REM Jekyll, alt cizgiyle baslayan dosyalari yok sayar ve derlemeyi bozabilir.
REM Bos .nojekyll dosyasi GitHub Pages'e "dokunma, oldugu gibi yayinla" der.
type nul > "%CIKTI%\.nojekyll"
if not exist "%CIKTI%\.nojekyll" goto :hata_nojekyll
echo .nojekyll tamam.

echo.
echo ============================================
echo  [3/3] gh-pages dalina itiliyor...
echo ============================================
pushd "%CIKTI%"
if errorlevel 1 goto :hata_cd

REM Her yayinda TAZE depo: gecmis tutmuyoruz, dal her seferinde bastan yazilir.
if exist ".git" rmdir /s /q ".git"
if errorlevel 1 goto :hata_git

git init
if errorlevel 1 goto :hata_git
git config user.name "myoru"
if errorlevel 1 goto :hata_git
git config user.email "211727797+yorulmaz91@users.noreply.github.com"
if errorlevel 1 goto :hata_git
git add -A
if errorlevel 1 goto :hata_git
git commit -m "Yayin"
if errorlevel 1 goto :hata_git
git branch -M gh-pages
if errorlevel 1 goto :hata_git
git remote add origin "%ORIGIN%"
if errorlevel 1 goto :hata_git
git push -f origin gh-pages
if errorlevel 1 goto :hata_push
popd

echo.
echo ============================================
echo  TAMAM - yayinlandi.
echo.
echo  Adres:  https://yorulmaz91.github.io/dovus_oyunu/
echo.
echo  Ilk yayinda GitHub'in siteyi ayaga kaldirmasi birkac
echo  dakika surer. Sayfa 404 verirse once depo ayarlarindan
echo  Pages'i ac:
echo    Settings ^> Pages ^> Source = "Deploy from a branch"
echo    Branch = gh-pages / (root) ^> Save
echo ============================================
goto :son

:hata_godot
echo.
echo HATA: Godot bulunamadi:
echo   %GODOT%
echo Yolu bu dosyanin basindaki GODOT satirinda duzelt.
goto :son

:hata_export
echo.
echo HATA: Web derlemesi basarisiz.
echo Muhtemel sebep: dis aktarim sablonlari kurulu degil.
echo Olmasi gereken klasor:
echo   %%APPDATA%%\Godot\export_templates\4.7.1.stable\web_nothreads_release.zip
goto :son

:hata_nojekyll
echo.
echo HATA: .nojekyll dosyasi olusturulamadi (%CIKTI%).
goto :son

:hata_cd
echo.
echo HATA: Derleme klasorune girilemedi: %CIKTI%
goto :son

:hata_git
echo.
echo HATA: git adimlarindan biri basarisiz oldu.
echo git kurulu mu? "git --version" ile bak.
popd
goto :son

:hata_push
echo.
echo HATA: gh-pages dalina itilemedi.
echo - Internet baglantisini kontrol et.
echo - GitHub kimligin gecerli mi? "git ls-remote %ORIGIN%" ile dene.
popd
goto :son

:son
echo.
pause
endlocal
