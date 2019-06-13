cd %~dp0/..

@set BUNDLE_GEMFILE=%CD%/Gemfile
@set APP_ENV=dev
@start /D %CD% ruby boot.rb
