cronJob = require('cron')
cronDate= require('cron').Date

config  = require "../config"
RES = require "../infra/RES"

Mailer = require ("../services/s-email-transport")
dbEmailService = require "../services/s-email"

Q = require "q"

module.exports.log = require("../../src/infra/log").getLoggerForModule(module)
log = module.exports.log

module.exports.setLog = (newLog) ->
    log = newLog

class Checker
    
    constructor: (@config) ->
        self = this
        try
            @clearOldJob = new cronJob.CronJob @config.clearOldCronJobPattern, (() -> self.clearOld()), undefined, true, #"UTC"
            log.info 'clearOldJob created, cronTab: ' + @config.clearOldCronJobPattern
        catch ex
            throw  new Error('clearOldJob failed to create:' + ex)

        try
            @handlePendingsJob = new cronJob.CronJob @config.handlePendingsCronJobPattern, (() -> self.handlePendings()), undefined, true#, "UTC"
            log.info 'handlePendingsJob created, cronTab: ' + @config.handlePendingsCronJobPattern
        catch ex
            throw  new Error('handlePendingsJob failed to create:' + ex)
            
        @someVal = new cronJob.CronJob @config.handlePendingsCronJobPattern, (() -> self.handlePendings()), undefined, true#, "UTC"
        @someVal1 = new cronJob.CronJob @config.handlePendingsCronJobPattern, (() -> self.handlePendings()), undefined, true#, "UTC"
        
        try
            @handleFailedJob = new cronJob.CronJob @config.handleFailedCronJobPattern, (() -> self.handleFailed()), undefined, true#, "UTC"
            log.info 'handleFailedJob created, cronTab: ' + @config.handleFailedCronJobPattern
        catch ex
            throw  new Error('handleFailedJob failed to create:' + ex)


    clearOld: (callback) ->
        log.info '------ clearOldJob started ------'
        dbEmailService.removeOld (err, numberOfDocs) ->
            if err?
                log.error 'clearOldJob: dbEmailService.removeOld error: ', err.message
                if callback?
                    return callback err
            else
                if numberOfDocs != 0 then log.info 'clearOld: ', numberOfDocs, "documents removed"
                else log.debug 'clearOldJob: no old documents found, ending job'
                if callback?
                    return callback null, numberOfDocs

    handlePendings: (callback)->
        log.info '------ handlePendingsJob started ------'
        self = this
        dbEmailService.getPendingList (err, list) ->
            if err?
                log.error 'handlePendingsJob: dbEmailService.getPendingList error: ', err.message
                callback err if callback?
                return 
            if list.length == 0
                log.debug 'handlePendingsJob: no pending documents, ending job'
                callback null if callback?
                return
            log.debug 'handlePendingsJob: handlePendingsJob has detected ' + list.length + ' pending documents, sending...'
            self.sendDocs list, (err, sendDocsResult) ->
                if err?
                    log.error 'handlePendingsJob: dbEmailService.sendDocs error: ', err.message
                    callback err if callback?
                    return 
                self.markDocs sendDocsResult, callback 


    handleFailed: (callback) ->
        log.info '------ handleFailedJob started ------'
        self = this
        dbEmailService.getFailedList (err, list) ->
            if err?
                log.error 'handleFailedjob: dbEmailService.getFailedList error: ', err.message
                callback err if callback?
                return
            if list.length == 0
                log.debug 'handleFailedjob: no failed documents, ending job'
                callback null if callback?
                return
            self.sendDocs list, (err, sendDocsResult) ->
                if err?
                    log.error 'handleFailedjob: handleFailed dbEmailService.sendDocs error: ', err.message
                    callback err if callback?
                    return 
                self.markDocs sendDocsResult, callback
                
                
    markDocs: (sendDocsResult, callback) ->
        #console.log 'markDocs start'
        if sendDocsResult? == false 
            if callback?        
                callback RES.INVALID_SEND_RESULT

        sentDefer = Q.defer()
        if sendDocsResult.sent?.length != 0
            log.info 'marking ' + sendDocsResult.sent.length + ' sent documents:' 
            dbEmailService.markAsSent sendDocsResult.sent, (err, numberOfSentDocsMarked) ->
                if err?
                    sentDefer.resolve 0
                    log.error 'handlePendings: markAsFailed error ', err.message 
                else 
                    sentDefer.resolve numberOfSentDocsMarked
        else
            sentDefer.resolve 0    

        failedDefer = Q.defer()
        if sendDocsResult.failed?.length != 0
            log.info 'marking ' + sendDocsResult.failed.length + ' failed documents.'
            dbEmailService.markAsFailed sendDocsResult.failed, (err, numberOfFailedDocsMarked) ->
                if err?
                    failedDefer.resolve 0
                    log.error 'handlePendings: markAsFailed error ', err.message
                else
                    failedDefer.resolve numberOfFailedDocsMarked
        else
            failedDefer.resolve 0
        
        Q.all([failedDefer.promise, sentDefer.promise]).spread (failed, sent) ->
            sendDocsResult.failedMarked = failed
            sendDocsResult.sentMarked = sent
            log.debug sendDocsResult.sentMarked + ' sent docs and ', sendDocsResult.failedMarked + ' failed docs was handled'

            if callback?
                callback null, sendDocsResult

#------------------------------------
    sendDocs: (docs, callback)->

        if docs? == false
            if callback?
                return callback RES.INVALID_ARGUMENTS

        sendDocsResult = {
            failed: []
            errorList: []
            sent: []
            responseList: []
        }
        
        promises = []
        
        for doc in docs
            mailer = new Mailer.Mailer config.mailTransportType, config.mailTransportConfig
            
            defer = Q.defer()
            promises.push(defer.promise)

            mailer.send doc, (err, result) ->
                if err?
                    log.error err.message
                    log.error 'failed document: ' + doc.subject + ', to:' + doc.to +
                              (if doc.cc? then ', cc: ' + doc.cc else '') +
                              (if doc.bcc? then ', bcc: ' + doc.cc else '')
                    defer.resolve err
                else
                    if result.failedRecipients?
                        failedRecipients = (rcp + (if idx > 0 then ', ' else '') for rcp in result.failedRecipients when rcp?)
                        log.error 'detected failed recipients in message with id [' + result.messageId + ']: ' + failedRecipients                    
                    defer.resolve true

        Q.all(promises).then (arrayOfResults) ->
    
            for res, i in arrayOfResults
                if res == true
                    sendDocsResult.sent.push(docs[i])
                else
                    sendDocsResult.failed.push(docs[i])
                    sendDocsResult.errorList.push(res)

            callback null, sendDocsResult
                    
module.exports.Checker = Checker