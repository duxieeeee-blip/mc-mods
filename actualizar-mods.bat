@echo off
chcp 65001 >nul
title Actualizar mods del servidor
set "DIR=%APPDATA%\.minecraft"
if not exist "%DIR%" mkdir "%DIR%"
cd /d "%DIR%"
where java >nul 2>nul
if errorlevel 1 (
  echo No se encontro Java. Instala Java 17 desde https://adoptium.net y vuelve a abrir este archivo.
  pause
  exit /b 1
)
if not exist packwiz-installer-bootstrap.jar (
  echo Descargando el instalador de mods...
  powershell -NoProfile -Command "Invoke-WebRequest 'https://duxieeeee-blip.github.io/mc-mods/packwiz-installer-bootstrap.jar' -OutFile 'packwiz-installer-bootstrap.jar'"
)
echo Actualizando mods en %DIR%\mods ...
java -jar packwiz-installer-bootstrap.jar -g -s client https://duxieeeee-blip.github.io/mc-mods/pack.toml
echo.
echo Listo. Ya podes abrir Minecraft con Forge 1.20.1.
pause
