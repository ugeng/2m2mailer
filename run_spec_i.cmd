@set NODE_ENV=test
node  "%~dp0\node_modules\mocha\bin\mocha" --timeout 5000 ./test-i --reporter spec --recursive --compilers coffee:coffee-script


