:: Clojure-tools provides official Clojure releases: https://github.com/clojure/brew-install/releases
:: However, for sake of reproducibility, we prefer to build clojure from source. The build is a bit convoluted:
:: 1. Install clojure-tools as a bootstrapping Clojure powershell Module
:: 2. Extract licenses (third-party) from the clojure source
:: 3. Build clojure from source and install into the local maven repository: ~/.m2/repository
:: 4. Build clojure-tools from source: This packages the clojure.jar into an installable/callable Module
:: 5. Install clojure-tools Module

:: @echo off
setlocal EnableDelayedExpansion

call :extract_licenses
call :create_activation_scripts

call :install_clojure_module "%SRC_DIR%\clojure-tools" "%SRC_DIR%\_conda-bootstrapped"
call :install_clojure_scripts "%SRC_DIR%\_conda-bootstrapped"
set "PSModulePath=%SRC_DIR%\_conda-bootstrapped\WindowsPowerShell\Modules;%PSModulePath%"
set "PATH=%SRC_DIR%\_conda-bootstrapped\Scripts;%PATH%"
call :build_clojure_from_source "%SRC_DIR%\clojure-src" "%SRC_DIR%\_conda-clojure-build"
if errorlevel 1 (
    echo "Failed to build clojure from source"
    exit 1
    )
call :build_clojure_tools "%SRC_DIR%\clojure-tools-src" "%SRC_DIR%\_conda-tools-build"
if errorlevel 1 (
    echo "Failed to build clojure-tools from source"
    exit 1
    )
call :install_clojure_module "%SRC_DIR%\_conda-tools-build\target" "%PREFIX%"
if errorlevel 1 (
    echo "Failed to install clojure built from source"
    exit 1
    )

goto :EOF

:: --- Functions ---

:extract_licenses
cd %SRC_DIR%\clojure-src
  call mvn license:add-third-party -DlicenseFile=THIRD-PARTY.txt > nul
  if errorlevel 1 exit 1
cd %SRC_DIR%

copy %SRC_DIR%\clojure-src\epl-v10.html %RECIPE_DIR%\epl-v10.html > nul
copy %SRC_DIR%\clojure-src\target\generated-sources\license\THIRD-PARTY.txt %RECIPE_DIR%\THIRD-PARTY.txt > nul
dir %RECIPE_DIR%\epl-v10.html %RECIPE_DIR%\THIRD-PARTY.txt
if not exist %RECIPE_DIR%\epl-v10.html (
    echo "Failed to copy epl-v10.html"
    exit 1
    )
if not exist %RECIPE_DIR%\THIRD-PARTY.txt (
    echo "Failed to copy THIRD-PARTY.txt"
    exit 1
    )
goto :EOF

:create_activation_scripts
for %%a in (activate deactivate) do (
  mkdir %PREFIX%\etc\conda\%%a.d
  for %%b in (bat ps1) do (
    copy %RECIPE_DIR%\scripts\%%a.%%b %PREFIX%\etc\conda\%%a.d\clojure-%%a.%%b > nul
    if errorlevel 1 exit 1
    echo copied %PREFIX%\etc\conda\%%a.d\clojure-%%a.%%b
  )
)
goto :EOF

:install_clojure_scripts
set "_PREFIX=%~1"
mkdir %_PREFIX%\Scripts
for %%a in (clojure clj) do (
  copy %RECIPE_DIR%\scripts\%%a.bat %_PREFIX%\Scripts\%%a.bat > nul
  if errorlevel 1 exit 1
  echo copied Scripts\%%a.bat
)
goto :EOF

:install_clojure_module
set "_CLOJURE_TOOLS=%~1"
set "_PREFIX=%~2"
powershell New-Item -ItemType Directory -Path "%_PREFIX%\WindowsPowerShell\Modules\ClojureTools" -Force
if errorlevel 1 (
    echo "Failed to create directory"
    exit /b 1
)

powershell Move-Item -Path "%_CLOJURE_TOOLS%" -Destination "%PKG_VERSION%" -Force
if errorlevel 1 (
    echo "Failed to move clojure-tools to PKG_VERSION"
    exit /b 1
)

powershell Move-Item -Path "%PKG_VERSION%" -Destination "%_PREFIX%\WindowsPowerShell\Modules\ClojureTools" -Force
if errorlevel 1 (
    echo "Failed to move PKG_VERSION to ClojureTools"
    exit /b 1
)
goto :EOF

:build_clojure_from_source
set "_CLOJURE_SRC=%~1
set "_BUILD_DIR=%~2

mkdir %_BUILD_DIR%
cd %_BUILD_DIR%
  xcopy /E %_CLOJURE_SRC%\* . > nul
  call mvn package -DskipTests > nul
  call mvn install:install-file -Dfile="target/clojure-%PKG_SRC_VERSION%.jar" -DgroupId=org.clojure -DartifactId=clojure -Dversion="%PKG_SRC_VERSION%" -Dpackaging=jar > nul
  if errorlevel 1 exit 1
cd %SRC_DIR%
goto :EOF

:build_clojure_tools
set "_CLOJURE_TOOLS_SRC=%~1"
set "_BUILD_DIR=%~2"

mkdir %_BUILD_DIR%
cd %_BUILD_DIR%
  xcopy /E %_CLOJURE_TOOLS_SRC%\* . > nul
  powershell Import-Module ClojureTools
  powershell -Command "ClojureTools\clojure -T:build release" > nul
  if errorlevel 1 exit 1
  if not exist target (
    echo "Failed to build clojure-tools: target directory not found"
    exit 1
  )
cd %SRC_DIR%
goto :EOF

