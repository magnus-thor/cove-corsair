@echo off
REM =======================================================
REM  Cove Corsair - Level Document Synchronization Script
REM  Applies parameter changes from documents/levels/*.md
REM  to Godot level resources in src/data/resources/levels/
REM =======================================================

echo.
echo =======================================================
echo    SYNCING LEVEL DOCUMENTS WITH GAME RESOURCES...
echo =======================================================
echo.

where python >nul 2>nul
if %ERRORLEVEL% equ 0 (
    python src\tools\sync_level_docs.py %*
    goto :done
)

where py >nul 2>nul
if %ERRORLEVEL% equ 0 (
    py src\tools\sync_level_docs.py %*
    goto :done
)

if exist "D:\Downloads\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64.exe" (
    "D:\Downloads\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64.exe" --headless --script src\tools\sync_level_docs.gd
    goto :done
)

echo ERROR: Neither Python nor Godot was found to execute synchronization!
exit /b 1

:done
echo.
echo =======================================================
echo    SYNCHRONIZATION FINISHED!
echo =======================================================
echo.
