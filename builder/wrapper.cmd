@echo off
@set SELFDIR=%~dp0
@cd %SELFDIR%
@set BUNDLE_GEMFILE=%SELFDIR%\lib\app\Gemfile
@set BUNDLE_IGNORE_CONFIG=

@%SELFDIR%\lib\ruby\bin\ruby.exe %SELFDIR%\lib\app\boot
