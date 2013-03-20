require '../infra/db'
collections = require '../infra/db/collections'
RES = require '../infra/RES'
EmailStatus = require '../infra/email/email-status-enum' 

log = require('../infra/log').getLoggerForModule(module)
module.exports.log = log #just for unit-testing

module.exports.setLog = (newLog) ->
    log = newLog

module.exports.getPendingList = (callback) ->
  
    collections.emails.findAsArray {status: EmailStatus.PENDING}, {w: 0}, (err, docs) ->
        if err?
            log.error('getPendingList: findAsArray error', err)
            return callback RES.INTERNAL_ERROR
        return callback null, docs

module.exports.getSentList = (callback) ->

    collections.emails.findAsArray {status: EmailStatus.SENT }, {w: 0}, (err, docs) ->
        if err?
            log.error('getSentList: findAsArray error', err)
            return callback RES.INTERNAL_ERROR
        return callback null, docs


module.exports.getFailedList = (callback) ->

    collections.emails.findAsArray {status: EmailStatus.ERROR }, {w: 0}, (err, docs) ->
        if err?
            log.error('getFailedList: findAsArray error', err)
            return callback RES.INTERNAL_ERROR
        return callback null, docs


module.exports.markAsSent = (list, callback) ->

    return callback RES.INVALID_ARGUMENTS if list?.length == 0
    
    ids = (item._id for item in list)

    query = {_id: {$in: ids}}
    sort = [['_id', -1]]
    set = { $set: {status: EmailStatus.SENT, dateSent: new Date()}}

    collections.emails.update query, set, {w:1, upsert:false, fsync:true, multi:true}, (err, numberOfDocs) ->
        if err?
            log.error 'markAsSent: update error', err
            return callback RES.INTERNAL_ERROR
        if err? == false and numberOfDocs != ids.length
            log.error 'markAsSent: error while updating multiple documents'
            return callback RES.UPDATE_NOT_ALL_DOCUMENTS_INVOLVED, numberOfDocs
        return callback null, numberOfDocs

module.exports.markAsFailed = (list, callback) ->

    return callback RES.INVALID_ARGUMENTS if list?.length == 0
    
    ids = (item._id for item, idx in list)

    query = {_id: {$in: ids}}
    sort = [['_id', -1]]
    set = { $set: {status: EmailStatus.ERROR}, $inc: { attempts : 1 } }

    collections.emails.update query, set, {w:1, fsync:true, multi:true}, (err, numberOfDocs) ->
        if err?
            log.error('markAsFailed: update error', err)
            return callback RES.INTERNAL_ERROR
        if err? == false and numberOfDocs != ids.length
            log.error('markAsFailed: error while updating multiple documents')
            return callback RES.UPDATE_NOT_ALL_DOCUMENTS_INVOLVED, numberOfDocs
        callback null, numberOfDocs

module.exports.removeOld = (callback) ->

    currentDate = new Date()
    oldDate = new Date()
    oldDate.setMonth(currentDate.getMonth() - 1)
    query = {dateCreated: {$lte: oldDate}, status: { $ne: EmailStatus.PENDING } }
    collections.emails.remove query, {w:1, fsync:true}, (err, numberOfDocs) ->
        if err?
            log.error('removeOld: remove error', err)
            return callback RES.INTERNAL_ERROR
        callback null, numberOfDocs