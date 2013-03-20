/**
* Mocha JsTestDriver Adapter.
* @author jan@prachar.eu (Jan Prachar)
*/
(function(){

/**
* Our mocha setup
*/
    var setup = mocha.setup;
    var mochaOptions = {};
    
    mocha.setup = function (opts) {
        if ('string' === typeof opts) {
        mochaOptions.ui = opts;
        } else {
        mochaOptions = opts;
    }
    
    setup.call(mocha, mochaOptions);
};

var getReporter = function (onTestDone, onComplete) {
var Base = mocha.reporters.Base;
var Reporter = function (runner) {
var self = this;

Base.call(this, runner);
this.onTestDone = onTestDone;
this.onComplete = onComplete;

this.reset = function () {
jstestdriver.console.log_ = [];
};

this.reset();

runner.on('start', function () {
});

runner.on('suite', function (suite) {
});

runner.on('suite end', function (suite) {
});

runner.on('test', function (test) {
self.reset();
});

runner.on('pending', function () {
});

runner.on('pass', function (test) {
self.onTestDone(new jstestdriver.TestResult(
test.parent.fullTitle(),
test.title,
'passed',
'',
'',
test.duration
));
});

runner.on('fail', function (test, err) {
var message = {
message: err.message,
name: '',
stack: err.stack
};
self.onTestDone(new jstestdriver.TestResult(
test.parent.fullTitle(),
test.title,
'failed',
jstestdriver.angular.toJson([message]),
'',
test.duration
));
});

runner.on('end', function () {
self.onComplete();
});
};

// Inherit from Base.prototype
Reporter.prototype.__proto__ = Base.prototype;

return Reporter;
};

var MOCHA_TYPE = 'mocha test case';
TestCase('Mocha Adapter Tests', null, MOCHA_TYPE);

jstestdriver.pluginRegistrar.register({

name: 'mocha',

getTestRunsConfigurationFor: function (testCaseInfos, expressions, testRunsConfiguration) {
for (var i = 0; i < testCaseInfos.length; i++) {
if (testCaseInfos[i].getType() === MOCHA_TYPE) {
testRunsConfiguration.push(new jstestdriver.TestRunConfiguration(testCaseInfos[i], []));
}
}
},

runTestConfiguration: function (config, onTestDone, onComplete) {
if (config.getTestCaseInfo().getType() !== MOCHA_TYPE) return false;

mochaOptions.reporter = getReporter(onTestDone, onComplete);
mocha.setup(mochaOptions);
mocha.run();
return true;
},

onTestsFinish: function () {

}

});

})();