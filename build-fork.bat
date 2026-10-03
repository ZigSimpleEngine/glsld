@echo off
rem glsld (fork): сборка сервера + упаковка расширения + установка в VSCode
setlocal EnableExtensions
chcp 65001 >nul
cd /d "%~dp0"

if not defined VCPKG_ROOT set "VCPKG_ROOT=D:\Programs\vcpkg"

echo [1/6] Проверка инструментов...
set "DEVENV="
for %%D in (
    "D:\Programs\VisualStudio\Products\Common7\IDE\devenv.com"
    "D:\Programs\VisualStudio\Bin\Common7\IDE\devenv.com"
    "%ProgramFiles%\Microsoft Visual Studio\18\Insiders\Common7\IDE\devenv.com"
) do if exist "%%~D" if not defined DEVENV set "DEVENV=%%~D"
if not defined DEVENV (
    echo ОШИБКА: devenv.com не найден. Нужен Visual Studio с C++ workload.
    exit /b 1
)
where node >nul 2>nul
if errorlevel 1 (
    echo ОШИБКА: node не найден в PATH.
    exit /b 1
)
where npm >nul 2>nul
if errorlevel 1 (
    echo ОШИБКА: npm не найден в PATH.
    exit /b 1
)
if not exist "%VCPKG_ROOT%\vcpkg.exe" (
    echo ОШИБКА: vcpkg.exe не найден в %VCPKG_ROOT%.
    exit /b 1
)
set "CODECMD="
for /f "delims=" %%C in ('where code 2^>nul') do if not defined CODECMD set "CODECMD=%%C"
if not defined CODECMD for %%C in (
    "D:\Programs\MicrosoftVSCode\bin\code.cmd"
    "%LOCALAPPDATA%\Programs\Microsoft VS Code\bin\code.cmd"
) do if exist "%%~C" if not defined CODECMD set "CODECMD=%%~C"
if not defined CODECMD (
    echo ОШИБКА: VSCode CLI ^(code^) не найден.
    exit /b 1
)
echo OK: devenv, node, vcpkg, code найдены.

echo [2/6] Проверка названия форка...
node "VSCodeExtension\scripts\ensure-fork-branding.mjs"
if errorlevel 1 (
    echo ОШИБКА: не смог обновить package.json.
    exit /b 1
)

echo [3/6] Сборка сервера Release x64 (первый раз долго: vcpkg ставит зависимости)...
"%DEVENV%" glsld.slnx /build "Release|x64" /project glsld
if errorlevel 1 (
    echo Стандартная сборка не удалась, пробую запасной путь через MSBuild...
    call :build_fallback
    if errorlevel 1 (
        echo ОШИБКА: сборка сервера не удалась.
        exit /b 1
    )
)
if not exist "glsld\Win64\glsld.exe" (
    echo ОШИБКА: glsld\Win64\glsld.exe не появился после сборки.
    exit /b 1
)
goto build_done

:build_fallback
set "VSROOT=%DEVENV:\Common7\IDE\devenv.com=%"
set "MSBUILD18=%VSROOT%\MSBuild\Current\Bin\amd64\MSBuild.exe"
set "VCVARS=%VSROOT%\VC\Auxiliary\Build\vcvars64.bat"
if not exist "%MSBUILD18%" (
    echo ОШИБКА: MSBuild не найден: %MSBUILD18%
    exit /b 1
)
if not exist "%VCVARS%" (
    echo ОШИБКА: vcvars64.bat не найден: %VCVARS%
    exit /b 1
)
call "%VCVARS%" >nul
set CL=/utf-8
if not exist "glsld\Win64" mkdir "glsld\Win64"
"%MSBUILD18%" mimalloc\mimalloc.vcxproj /p:Configuration=Release /p:Platform=x64 "/p:SolutionDir=%CD%\\" /p:CheckMSVCComponents=false /p:UseEnv=true /verbosity:minimal
if exist "x64\Release\mimalloc.lib" copy /y "x64\Release\mimalloc.lib" "glsld\Win64\mimalloc.lib" >nul
set "LIB=%CD%\glsld\Win64;%LIB%"
"%MSBUILD18%" glsld.slnx /p:Configuration=Release /p:Platform=x64 /p:CheckMSVCComponents=false /p:UseEnv=true /verbosity:minimal
exit /b %errorlevel%

:build_done

echo [4/6] Раскладка сервера в расширение...
if not exist "VSCodeExtension\bin\Win64" mkdir "VSCodeExtension\bin\Win64"
copy /y "glsld\Win64\glsld.exe" "VSCodeExtension\bin\Win64\glsld.exe" >nul
if errorlevel 1 (
    echo ОШИБКА: не смог скопировать glsld.exe.
    exit /b 1
)
for %%L in ("glsld\Win64\*.dll") do copy /y "%%L" "VSCodeExtension\bin\Win64\" >nul
if exist "VSCodeExtension\bin\Database" rmdir /s /q "VSCodeExtension\bin\Database"
xcopy "glsld\Database" "VSCodeExtension\bin\Database\" /e /i /y /q
if errorlevel 1 (
    echo ОШИБКА: не смог скопировать Database.
    exit /b 1
)

echo [5/6] Сборка и упаковка расширения...
pushd VSCodeExtension
call npm ci
if errorlevel 1 (
    echo ОШИБКА: npm ci не удался.
    popd
    exit /b 1
)
call npm run compile
if errorlevel 1 (
    echo ОШИБКА: npm run compile не удался.
    popd
    exit /b 1
)
del glsld-fork-*.vsix 2>nul
call npx -y @vscode/vsce package --target win32-x64
if errorlevel 1 (
    echo ОШИБКА: упаковка vsix не удалась.
    popd
    exit /b 1
)
set "VSIX="
for %%F in (glsld-fork-*.vsix) do set "VSIX=%%F"
if not defined VSIX (
    echo ОШИБКА: vsix-файл не создан.
    popd
    exit /b 1
)
popd

echo [6/6] Установка %VSIX% в VSCode...
call "%CODECMD%" --install-extension "VSCodeExtension\%VSIX%" --force
if errorlevel 1 (
    echo ОШИБКА: установка расширения не удалась.
    exit /b 1
)

echo ГОТОВО: glsld (fork) установлено. Перезапусти VSCode.
