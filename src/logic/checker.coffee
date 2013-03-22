cronJob = require('cron')
cronDate= require('cron').Date

config  = require "../config"
RES = require "../infra/RES"

mailer = require ("../services/s-email-transport")
dbEmailService = require "../services/s-email"

When = require 'when'

module.exports.log = require("../../src/infra/log").getLoggerForModule(module)
log = module.exports.log

module.exports.setLog = (newLog) ->
    log = newLog
#------------------------------------
class Checker
    
    constructor: (@config) ->
        self = this
        try
            @clearOldJob = new cronJob.CronJob @config.clearOldCronJobPattern, (() -> self.clearOld()), undefined, true, #"UTC"
            log.info 'clearOldJob created, cronTab: ' + @config.clearOldCronJobPattern
        catch ex
            throw  new Error('clearOldJob failed to create:' + ex)

        try
            #@handlePendingsJob = new cronJob.CronJob @config.handlePendingsCronJobPattern, (() -> self.handlePendings()), undefined, true#, "UTC"
            @handlePendingsJob = new cronJob.CronJob @config.handlePendingsCronJobPattern, self.handleJob.bind(self, 'pending', dbEmailService.getPendingList), undefined, true
            log.info 'handlePendingsJob created, cronTab: ' + @config.handlePendingsCronJobPattern
        catch ex
            throw  new Error('handlePendingsJob failed to create:' + ex)
       
        try
            #@handleFailedJob = new cronJob.CronJob @config.handleFailedCronJobPattern, (() -> self.handleFailed()), undefined, true#, "UTC"
            @handleFailedJob = new cronJob.CronJob @config.handleFailedCronJobPattern, self.handleJob.bind(self, 'failed', dbEmailService.getFailedList), undefined, true
            log.info 'handleFailedJob created, cronTab: ' + @config.handleFailedCronJobPattern
        catch ex
            throw  new Error('handleFailedJob failed to create:' + ex)
#------------------------------------
    clearOld: (callback) ->
        log.info '------ clearOldJob started ------'
        dbEmailService.removeOld (err, numberOfDocs) ->
            if err?
                log.error 'clearOldJob: dbEmailService.removeOld error: %j', err
                if callback?
                    return callback err
            else
                if numberOfDocs != 0 then log.info "clearOld: %d documents removed", numberOfDocs 
                else log.debug 'clearOldJob: no old documents found, ending job'
                if callback?
                    return callback null, numberOfDocs
#------------------------------------
    handleJob: (jobPrefix, getListFunc, callback) ->
        jobName = jobPrefix + 'Job'
        log.info '------ %s started ------', jobName || ''
        self = this
        getListFunc (err, list) ->
            if err?
                log.error '%s: dbEmailService.getPendingList error: %j', jobName || '', err
                callback? err
                return
            if list.length == 0
                log.debug '%s: no %s documents, ending job', jobName, jobPrefix
                callback? null
                return
            log.info '%s: %d documents was detected, sending...', jobName || '', list.length
    
            When self.sendDocs(list), (results) ->
                    success = (result.doc for result in results when result.success == true)
                    failed = (result.doc for result in results when result.success != true)
                    self.forSuccessfull(success, jobName) if success.length > 0
                    self.forFailed(failed, jobName) if failed.length > 0
                    callback? null, results
                
#------------------------------------
    forSuccessfull: (successDocs, jobName) ->
        log.debug '%s: %d documents has been sent', jobName || '', successDocs?.length
        dbEmailService.markAsSent successDocs, (err, numberOfSentDocsMarked) ->
            if err?
                log.error '%s: markAsSent error %j', jobName || '', err
            if numberOfSentDocsMarked != successDocs.length
                log.warn '%s: not all documents was marked as sent (sent: %d, marked: %d)', jobName || '', successDocs.length, numberOfSentDocsMarked
            else
                log.debug '%s: all sent documents was successfully marked', jobName || ''
#------------------------------------
    forFailed: (errDocs, jobName) ->
        log.error '%s: %d documents failed', jobName || '', errDocs?.length
        dbEmailService.markAsFailed errDocs, (err, numberOfFailedDocsMarked) ->
            if err?
                log.error '%s: markAsFailed error %j', jobName || '', err
            if numberOfFailedDocsMarked != errDocs.length
                log.warn '%s: not all documents was marked as failed (failed: %d, marked: %d)', jobName || '', errDocs.length, numberOfFailedDocsMarked
            else
                log.debug '%s: all failed documents was successfully marked', jobName || ''
#------------------------------------
    sendDoc: (doc)->
        defer = When.defer()
        _mailer = new mailer.Mailer config.mailTransportType, config.mailTransportConfig
        _mailer.send doc, (err, result) ->
            if err?
                log.error 'senDoc: %j', err
                log.debug 'failed document: ' + doc.subject + ', to:' + doc.to + (if doc.cc? then ', cc: ' + doc.cc else '') +  (if doc.bcc? then ', bcc: ' + doc.cc else '')
                defer.resolve {doc: doc, success: false }
            else
                log.debug 'doc sent: %j', result
                if result.failedRecipients? && result.failedRecipients.length > 0 
                    failedRecipients = (rcp + (if idx > 0 then ', ' else '') for rcp, idx in result.failedRecipients when rcp?)
                    log.error 'detected failed recipients in message with id [' + result.messageId + ']: ' + failedRecipients
                defer.resolve { doc: doc, success: true }

        return defer.promise;                
                
#------------------------------------
    sendDocs: (docs) ->
        if docs? == false || docs.length == 0
            return RES.INVALID_ARGUMENTS

        deferreds = []

        for doc, i in docs
            deferreds.push(@sendDoc(doc))

        When.all(deferreds)
#------------------------------------
module.exports.Checker = Checker