path = require 'path'

checker = require './logic/checker'

log = undefined

console.log "Starting..."
console.log "App file dirname: #{__dirname}"

config = require './config'


onExit = (code) ->
    log info 'closing DB connection...'
    require('./infra/db').shutdown()
    log info 'exiting...'
    process.exit(code)

go = () ->
    # конфигурируем логгирование
    logManager = require('./infra/log')
    global.logManager = logManager
    try
        logManager.configure(path.join(__dirname, 'logging.json'))
        console.log "Logger successfully initialized"
    catch ex
        console.log ex
        console.log "Logger initialization failed"

    log = logManager.getLoggerForModule(module)

    log.info "Running in " + process.env.NODE_ENV + ' environment'
    # конфигурируем БД
    require('./infra/db').init (err, db) ->
        if (err?)
            log.fatal "DB initialization failed: " + err
            setTimeout(( -> onExit(1)), 1000)
        else
            module.exports.db = db
            log.info "DB successfully initialized"

            require('./infra/db/collections').init(db)
            
            log.info "DB collections successfully initialized"

            require('./infra/db/db-indices').ensureIndices (indicesError, result) ->
                if indicesError?
                    log.fatal "DB indices initialization failed: " + indicesError.message
                    setTimeout(( -> onExit(1)), 1000)
                else
                    log.info "DB indices successfully initialized"
            
            # запуск почтового чекера
            try
                _checker = new checker.Checker(config.checker)
                log.info "mail checker successfully initialized"
            catch ex
                log.error "mail checker initialization failed: " + ex
                setTimeout(( -> onExit(1)), 1000)


go()