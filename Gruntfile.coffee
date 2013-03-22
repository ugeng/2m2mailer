path = require 'path'

module.exports = (grunt) ->

    config = {
    pkg: grunt.file.readJSON('package.json'),

    'watch-compile':
        options:
            sourcesFolders: [ 'src', 'test' ]
            buildFolder: '.build'
        watch:
            options:
                mode: 'watch'
        once:
            options:
                mode: 'once'
        'watch-redux':
            options:
                mode: 'watch'
                redux: true
        'once-redux':
            options:
                mode: 'once'
                redux: true
    }

    grunt.loadTasks('tasks');

    grunt.initConfig(config)

    grunt.registerTask('watch-redux', [ 'watch-compile:watch-redux' ]);
    grunt.registerTask('watch', [ 'watch-compile:watch' ]);
    grunt.registerTask('once-redux', [ 'watch-compile:once-redux' ]);
    grunt.registerTask('default', [ 'watch-compile:once' ]);