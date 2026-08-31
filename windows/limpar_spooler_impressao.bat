@echo off

title Limpa Spooler de Impressão

echo ---------------------------

echo Limpa Spooler de Impressão

echo ---------------------------

echo Pressione CTRL + C para sair

echo ---------------------------

cls

echo 33% Completo

net stop spooler

echo 66% Completo

cd %systemroot%\system32\spool\PRINTERS

del %systemroot%\system32\spool\PRINTERS\*.* /Q

del /f /s *.shd

del /f /s *.spl

cls

echo 100% Completo

net start spooler

cls

pause

echo.

exit %0
