module.exports = function(grunt) {

    return;

    // Concat source files and/or directives.
    grunt.registerHelper('wrap', function(file) {
        var data = grunt.file.read(file);
        var moduleId = undefined;
        var idStr = typeof dest !== 'undefined' ? '' + moduleId + ', ' : '';
        return 'define(' + idStr + 'function(require, exports, module) {\n' + data + '\n});';
    });

    // Create a new task.
    grunt.registerMultiTask('wrap', 'Wrap js module as AMD module', function() {
        //var files = grunt.file.expandFiles(this.file.src);
        var i, filedest, filesrc;

        var filesObject = {};
        if (this.data instanceof Array)
            for (i = 0; i < this.data.length; i++)
                filesObject[this.data[i]] = this.data[i]
        else
            filesObject = this.data;

        //console.log(filesObject);

        for(filedest in filesObject) {
            if (filesObject.hasOwnProperty(filedest)) {
                filesrc = filesObject[filedest];
                grunt.file.write(filedest, grunt.helper('wrap', filesrc));
                // Fail task if errors were logged.
                if (this.errorCount) { return false; }
                // Otherwise, print a success message.
                grunt.log.writeln('File ' + filesrc + ' AMD wrapped as ' + filedest);
            }
        }

    });
};