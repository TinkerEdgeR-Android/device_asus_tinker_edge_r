@ECHO OFF

PATH=%PATH%;"%CD%\tools"

Android_Console_Tool UF update.img

echo Press any key to exit...
pause >nul
exit