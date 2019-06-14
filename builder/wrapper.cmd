@echo off
@set SELFDIR=%~dp0
@cd %SELFDIR%
@set BUNDLE_GEMFILE=%SELFDIR%\lib\app\Gemfile
@set BUNDLE_IGNORE_CONFIG=

@start /MIN %SELFDIR%\lib\ruby\bin\ruby.cmd %SELFDIR%\lib\app\boot
