fs = require('fs')
coffee = require('coffee-script');
path = require('path')

module.exports = function(grunt) {

    // Concat source files and/or directives.
    var wrap = function(file) {
        var data = grunt.file.read(file);
        var moduleId = undefined;
        var idStr = typeof dest !== 'undefined' ? '' + moduleId + ', ' : '';
        return 'define(' + idStr + 'function(require, exports, module) {\n' + data + '\n});';
    };

    var getRunFolderFile = function (filePath) {
        "use strict";
        return path.join(buildFolder, filePath);
    };

    var compileCoffeeFileRedux = function (csFilePath, jsFilePath, createSourceMaps) {
        "use strict";
        var cs = {
            content: "",
            fileName: "#{targetFile.dest}.coffee"
        };
        var js = {
            content: "",
            fileName: targetFile.dest
        };
        var map = {
            content: "",
            fileName: "#{targetFile.dest}map.json"
        };
        var csSource = grunt.file.read(csFilePath);
        cs.ast = coffee.parse(csSource, { bare: options.bare, raw: options.raw || options.sourceMap });
        js.ast = coffee.compile(cs.ast, { bare: options.bare });
        js.content = coffee.js(js.ast);
    };

    var compileCoffeeFile = function (filePath, jsFilePath) {
        "use strict";
        try {
            grunt.log.ok('Compilation.. ' + filePath);
            var coffeeSrc = grunt.file.read(filePath);
            var jsSrc = coffee.compile(coffeeSrc, { bare: true });
            jsSrc = jsSrc.replace(/  /g, '    ');
            jsSrc = jsSrc.replace(/\t/g, '    ');
            grunt.file.write(jsFilePath, jsSrc);
            grunt.log.ok('File compiled ' + jsFilePath);
        } catch (exc) {
            grunt.log.error('Ошибка ' + exc);
            return false;
        }
        return true;
    };

    var fileChangedEvent = function(filePath) {
        "use strict";
        var path = getRunFolderFile(filePath);
        if (filePath.search(/.coffee$/) >= 0) {
            var jsPath = path.replace(/.coffee$/, '.js');
            compileCoffeeFile(filePath, jsPath);
        } else {
            try {
                grunt.log.ok('Copying.... ' + filePath);
                grunt.file.copy(filePath, path);
                //console.log(filePath + ' -> ' + path);
                grunt.log.ok('File copied ' + path);
            } catch (exc) {
                grunt.log.error('Ошибка ' + exc);
            }
        }
    };

    var watchrListener = function (eventName, filePath, fileCurrentStat, filePreviousStat) {
        "use strict";
        console.log(eventName + ' -> ' + filePath);
        if (eventName === 'update' || eventName === 'new') {
            if (fileCurrentStat.isFile() === false)
                return;
            fileChangedEvent(filePath);
        } else if (eventName === 'delete') {
            var path = getRunFolderFile(filePath);
            if (fs.existsSync(path))
                fs.unlinkSync(path);
        }
    };

    // defaults
    var once = 'once';
    var buildFolder = '.build';
    var sourcesFolders = [ 'src', 'test' ];

    // Create a new task.
    grunt.registerMultiTask('watch-compile-js', 'Watch __src folder and compile to __run', function () {

        once = this.options.once || once;
        buildFolder = this.options.buildFolder || buildFolder;
        sourcesFolders = this.options.sourcesFolders || sourcesFolders;

        if (sourcesFolders instanceof String)
            sourcesFolders = [ sourcesFolders ];

        var watchr = require('watchr');
        var path = require('path');

        //var taskDone = this.async();

        for (var i = 0; i < sourcesFolders.length; i++) {
            var sources = sourcesFolders[i];

            grunt.file.recurse(sources, function (abspath, rootdir, subdir, filename) {
                "use strict";
                fileChangedEvent(abspath);
            });

            if (this.data.mode !== 'once') {
                watchr.watch({
                    path: sources,
                    listener: watchrListener,
                    interval: 1000
                });
            }
        }

        return true;
    });
};