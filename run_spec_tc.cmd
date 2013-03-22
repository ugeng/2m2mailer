@set NODE_ENV=test
node  "%~dp0\node_modules\mocha\bin\mocha" --timeout 5000 ./test --reporter teamcity --recursive --compilers coffee:coffee-script


