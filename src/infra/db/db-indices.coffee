MongoDb = require('mongodb').Db
collections = require('./collections')
RES = require('../RES')

log = require('../log').getLoggerForModule(module)
exports.log = log #just for unit-testing

module.exports.setLog = (newLog) ->
    log = newLog

exports.ensureIndices = (callback) ->

    collections.emails.ensureIndex {status: 1}, {unique: false, w: 1}, (err, indexName) ->
        if err?
            log.fatal('Ensure "status" index error', err)
            return callback? err
        return callback?(null, RES.INDICES_ENSURED)