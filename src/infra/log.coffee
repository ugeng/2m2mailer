module.exports = require 'log4js'
module.exports.configure({ appenders: [ ], replaceConsole: false })

#------------------------------------
# helper stub log
module.exports.logStub = {
    debug: (message)->
    info: (message)->
    warn: (message)->
    error: (message)->
    fatal: (message)->
}

cachedLoggers = { }

module.exports.getLoggerForModule = (mod) ->
    filename = mod.filename
    idx = Math.max(filename.lastIndexOf('\\'), filename.lastIndexOf('/'))
    idxDot = filename.lastIndexOf('.')
    name = filename[idx+1..idxDot-1]
    if cachedLoggers[name]? == false
        cachedLoggers[name] = module.exports.getLogger(name)
    return cachedLoggers[name]