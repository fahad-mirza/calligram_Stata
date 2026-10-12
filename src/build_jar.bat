@echo off
:: Maintainer-only: rebuild calligram.jar after editing the Java sources or ui.js / ui.css.
:: Users never need this; they get the pre-built JAR via net install.
:: Requires a JDK 11+ (javac and jar on PATH). Edit SFI below to your Stata folder.
setlocal
set SFI=C:\Program Files\Stata18\utilities\jar\sfi-api.jar
cd /d "%~dp0"
if exist build rmdir /s /q build
mkdir build\calligram\fonts
javac --release 11 -encoding UTF-8 -cp "%SFI%" -d build calligram\Fonts.java calligram\Shapes.java calligram\Engine.java calligram\Counter.java calligram\Layout.java calligram\Cloud.java calligram\Render.java || goto :fail
copy /y calligram\ui.js build\calligram\ >nul || goto :fail
copy /y calligram\ui.css build\calligram\ >nul || goto :fail
:: bundled fonts and their licence files
copy /y calligram\fonts\*.* build\calligram\fonts\ >nul || goto :fail
jar cf ..\calligram.jar -C build calligram || goto :fail
rmdir /s /q build
echo Built ..\calligram.jar
pause
exit /b 0
:fail
echo Build failed.
pause
exit /b 1
