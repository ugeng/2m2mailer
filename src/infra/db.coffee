config = require('../config')

log = require('./log').getLoggerForModule(module)
module.exports.log = log #just for unit-testing

MongoDb = require('mongodb').Db
MongoDbCollection = require('mongodb').Collection


module.exports.setLog = (newLog) ->
    log = newLog
    
###
    findAsArray Расширение прототипа MongoDb.Collection для асинхронного получения массива полученных данных в колбеке "без лапши"
###    
if (MongoDbCollection.prototype.findAsArray? == false)
    MongoDbCollection.prototype.findAsArray = () ->

        return if arguments.length == 0
        callBack = arguments[arguments.length-1]
        return if typeof callBack != 'function'
        args = Array.prototype.slice.call(arguments, 0, arguments.length-1)

        cursor = this.find.apply(this, args)
        cursor.toArray (err, list) ->
            if err?
                log.error 'findAsArray: toArray error', err
                return callBack err
            return callBack null, list
        return undefined
###
    Events, emited by mongo-driver:
    * open - connection open
    * connect - 
    * error - db error
    * parseError -
    * message - some info
    * timeout - commection timeout
    * close - connection closed
    * poolReady - emited when connection pool is ready
    * connectionError - connection error with using replicaSet
    * fullsetup - at least one set is up (with replicaSet) 
###

exports.init = (callback) ->

    MongoDb.connect config.db.URL, (err, db) ->

        if err?
            log.fatal('MongoDB error', err)
            return callback err

        log.info 'connection on ' + config.db.URL + ' established'
        exports.nativeDb = db

        callback null, db

        
exports.shutDown = (callback) ->
    exports.nativeDb.close(callback)

   
exports.insertBigArray = insertBigArray = (col, array, num, callback) ->
    if array.length == 0
        callback null, "Success"
        return
    part = array.splice(0, Math.min(num, array.length))
    col.insert part, { safe:true }, (err) ->
        if err
            callback err
        else
            insertBigArray col, array, num, callback


