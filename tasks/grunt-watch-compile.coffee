fs = require("fs")
coffee = require("coffee-script")
coffeeRedux = require("coffee-script-redux")
path = require("path")
watchr = require("watchr")

module.exports = (grunt) ->

    class CoffeeCompiler
        constructor: (@buildFolder, @sourceMap = false, @bare = false) ->

        canHandle: (filename) ->
            return filename.match(/.coffee$/)

        getCsFilename: (originalFilename) ->
            return path.join buildFolder, originalFilename.replace(/.coffee$/, '.js')

        getMapFilename: (originalFilename) ->
            return path.join buildFolder, originalFilename.replace(/.coffee$/, '.js.map')

        fileChanged: (filepath) ->
            csSource = grunt.file.read filepath

            try
                destCoffee = @getCsFilename(filepath)
                destMap = @getMapFilename(filepath)
                answer = coffee.compile csSource, { bare: @bare, sourceMap: @sourceMap, filename: filepath }
                jsContent = if @sourceMap then answer.js else answer

                if @sourceMap
                    grunt.file.write destMap, answer.v3SourceMap
                    #grunt.file.write destMap, answer.sourceMap
                    grunt.log.ok "Map compiled #{destMap}"

                grunt.file.write destCoffee, jsContent
                grunt.log.ok "Coffee compiled #{destCoffee}"
            catch error
                console.log error
                console.log error.stack
                grunt.log.error "Error occured for file #{filepath}"
                grunt.log.error error


        fileRemoved: (filepath) ->
            try
                dest = @getCsFilename(filepath)
                fs.unlinkSync dest if fs.existsSync dest
                grunt.log.ok "File removed #{dest}"
                if @sourceMap
                    map = @getMapFilename(filepath)
                    fs.unlinkSync map if fs.existsSync map
                    grunt.log.ok "File removed #{map}"
            catch error
                grunt.log.error "Error occured for file #{filepath}"
                grunt.log.error error


    class CoffeeReduxCompiler
        constructor: (@buildFolder, @sourceMap = false, @bare = false, @raw = false) ->

        canHandle: (filename) ->
            return filename.match(/.coffee$/)

        getCsFilename: (originalFilename) ->
            return path.join buildFolder, originalFilename.replace(/.coffee$/, '.js')

        getMapFilename: (originalFilename) ->
            return path.join buildFolder, originalFilename.replace(/.coffee$/, '.js.map')

        fileChanged: (filepath) ->
            csSource = grunt.file.read filepath

            options =
                bare: @bare
                raw: @raw || @sourceMap

            try
                csAst = coffeeRedux.parse csSource, options
                jsAst = coffeeRedux.compile csAst, bare: @bare
                jsContent = coffeeRedux.js jsAst
                jsContent = jsContent.replace(RegExp("  ", "g"), "    ").replace(/\t/g, "    ")

                if @sourceMap
                    destMap = @getMapFilename(filepath)
                    mapContent = coffeeRedux.sourceMap jsAst, path.join(process.cwd(), filepath)
                    jsContent += "#{grunt.util.linefeed}//@ sourceMappingURL=#{path.basename destMap}"
                    grunt.file.write destMap, mapContent
                    grunt.log.ok "Map compiled #{destMap}"

                destCoffee = @getCsFilename(filepath)
                grunt.file.write destCoffee, jsContent
                grunt.log.ok "Coffee compiled #{destCoffee}"
            catch error
                grunt.log.error "Error occured for file #{filepath}"
                grunt.log.error error


        fileRemoved: (filepath) ->
            try
                dest = @getCsFilename(filepath)
                fs.unlinkSync dest if fs.existsSync dest
                grunt.log.ok "File removed #{dest}"
                if @sourceMap
                    map = @getMapFilename(filepath)
                    fs.unlinkSync map if fs.existsSync map
                    grunt.log.ok "File removed #{map}"
            catch error
                grunt.log.error "Error occured for file #{filepath}"
                grunt.log.error error

    class ContentCopier
        constructor: (@buildFolder) ->

        canHandle: (filename) ->
            return !filename.match(/.coffee$/)

        getFilename: (originalFilename) ->
            return path.join buildFolder, originalFilename

        fileChanged: (filepath) ->
            try
                dest = @getFilename(filepath)
                grunt.file.copy(filepath, dest)
                grunt.log.ok "File copied #{dest}"
            catch error
                grunt.log.error "Error occured for file #{filepath}"
                grunt.log.error error

        fileRemoved: (filepath) ->
            try
                dest = @getFilename(filepath)
                fs.unlinkSync dest if fs.existsSync dest
                grunt.log.ok "File removed #{dest}"
            catch error
                grunt.log.error "Error occured for file #{filepath}"
                grunt.log.error error

    # Concat source files and/or directives.
    wrap = (file) ->
        data = grunt.file.read(file)
        moduleId = `undefined`
        idStr = (if typeof dest isnt "undefined" then "" + moduleId + ", " else "")
        "define(" + idStr + "function(require, exports, module) {\n" + data + "\n});"

    fileChangedEvent = (filePath) ->
        try
            for worker in workers when worker.canHandle(filePath)
                worker.fileChanged(filePath)
        catch exc
            grunt.log.error error

    watchrListener = (eventName, filePath, fileCurrentStat, filePreviousStat) ->
        "use strict"
        console.log eventName + " -> " + filePath
        if eventName is "update" or eventName is "new"
            return if fileCurrentStat.isFile() is false
            fileChangedEvent(filePath)
        else if eventName is "delete"
            for worker in workers when worker.canHandle(filePath)
                worker.fileRemoved(filePath)


    # defaults
    mode = "once"
    buildFolder = ".build"
    sourcesFolders = ["src", "test"]

    workers = []

    # Create a new task.
    grunt.registerMultiTask "watch-compile", "Watch __src folder and compile to __run", ->

        options = @options()

        mode = options.mode or mode
        buildFolder = options.buildFolder or buildFolder
        sourcesFolders = options.sourcesFolders or sourcesFolders
        sourcesFolders = [sourcesFolders] if sourcesFolders instanceof String

        if (options.redux == true)
            workers.push new CoffeeReduxCompiler(buildFolder, true, true, false)
        else
            workers.push new CoffeeCompiler(buildFolder, true, false)

        workers.push(new ContentCopier(buildFolder))

        @async() if mode isnt 'once'

        for sourceFolder in sourcesFolders
            grunt.file.recurse sourceFolder, (abspath, rootdir, subdir, filename) ->
                "use strict"
                fileChangedEvent abspath

            if mode isnt 'once'
                watchr.watch
                    path: sourceFolder
                    listener: watchrListener
                    interval: 1000