process.env.NODE_ENV = 'test'
config = require '../../src/config'
checker = require('../../src/logic/checker')

#dependencies
cronJob = require 'cron'
Mailer = require '../../src/services/s-email-transport'
MailerLog = Mailer.log
dbEmailService = require '../../src/services/s-email'
mailDbServiceLog = dbEmailService.log

#helpers
db = require '../../src/infra/db'
collections = require '../../src/infra/db/collections'
emailStatus = require '../../src/infra/email/email-status-enum'
RES = require "../../src/infra/RES"
logStub = require('../../src/infra/log').logStub

stubEmails = []

mockChecker = (sandbox) ->
    cronJobMock = sandbox.mock(cronJob)
    cronJobMock.expects("CronJob").once().withArgs(config.checker.clearOldCronJobPattern).returns({})
    cronJobMock.expects("CronJob").once().withArgs(config.checker.handleFailedCronJobPattern).returns({})
    cronJobMock.expects("CronJob").once().withArgs(config.checker.handlePendingsCronJobPattern).returns({})
    new checker.Checker(config.checker)

insertStubEmails = (collection, callback) ->
    now = new Date()
    oldDate = new Date()
    oldDate.setTime(now.getTime() - 31*24*60*60*1000 - 60*1000)
    stubEmails =
        [ { subject: 'reg', body: 'hello', from: 'sender', to: 'address1@server.org', cc: ['addr11@server.org', 'addr12@server.org'], bcc: ['addr13@server.org', 'addr14@server.org'], status: emailStatus.SENT, dateCreated: oldDate},
            { subject: 'reg', body: 'hello', from: 'sender', to: 'address2@server.org', cc: ['addr21@server.org', 'addr22@server.org'], bcc: ['addr23@server.org', 'addr24@server.org'], status: emailStatus.PENDING, dateCreated: new Date() }
            { subject: 'reg', body: 'hello', from: 'sender', to: 'address3@server.org', cc: ['addr31@server.org', 'addr32@server.org'], bcc: ['addr33@server.org', 'addr34@server.org'], status: emailStatus.ERROR, dateCreated: oldDate, attempts: 1 }
        ]
    collection.remove () ->
        collection.insert stubEmails, {w: 1}, callback

#test frameworks
expect = require('chai').expect
assert = require('chai').assert
sinon = require('sinon')

xdescribe 'Checker', ->

    sandbox = {}

    before (done) ->
        # перенаправляем вывод штатных логов в заглушки, чтобы не засорять консоль
        checker.setLog(logStub)
        dbEmailService.setLog(logStub)
        done()
    
    beforeEach (done) ->
        sandbox = sinon.sandbox.create()
        db.init (err, db) ->
            collections.init(db)
            done()

    afterEach (done) ->
        sandbox.restore()
        db.shutDown done        
        done()

    describe 'constructor', () ->

        it 'нормальное создание объекта (BDD-style)', (done) ->
            
            returnVal = [{1}, {2}, {3}]

            cronJobMock = sandbox.mock(cronJob)
            expectation1 = cronJobMock.expects("CronJob").once().withArgs(config.checker.clearOldCronJobPattern).returns(returnVal[0])
            expectation2 = cronJobMock.expects("CronJob").once().withArgs(config.checker.handleFailedCronJobPattern).returns(returnVal[1])
            expectation3 = cronJobMock.expects("CronJob").once().withArgs(config.checker.handlePendingsCronJobPattern).returns(returnVal[2])

            _checker = new checker.Checker(config.checker)

            expect(_checker.clearOldJob).to.be.eql returnVal[0]
            expect(_checker.handleFailedJob).to.be.eql returnVal[1]
            expect(_checker.handlePendingsJob).to.be.eql returnVal[2]
            
            cronJobMock.verify()
            
            done()

        it 'нормальное создание объекта (integration-style)', (done) ->

            cronJobSpy = sandbox.spy(cronJob, "CronJob")

            _checker = new checker.Checker(config.checker)

            expect(cronJobSpy.calledThrice).to.be.true
            expect(_checker.clearOldJob.cronTime.source).to.be.eql config.checker.clearOldCronJobPattern
            expect(_checker.handlePendingsJob.cronTime.source).to.be.eql config.checker.handlePendingsCronJobPattern
            expect(_checker.handleFailedJob.cronTime.source).to.be.eql config.checker.handleFailedCronJobPattern
            
            done()

        it 'создание объекта с ошибкой (1) (BDD-style)', (done) ->

            ex = new Error("gsom!!!1")

            cronJobMock = sandbox.mock(cronJob)
            cronJobMock.expects("CronJob").once().withArgs(config.checker.clearOldCronJobPattern).throws(ex)

            error = undefined
            
            try
                _checker = new checker.Checker(config.checker)
            catch ex
                error = ex

            expect(error).to.not.be.undefined
            expect(error.message).to.include(ex.message)

            cronJobMock.verify()

            done()

        it 'создание объекта с ошибкой (1) (BDD-style)', (done) ->

            ex = new Error("gsom!!!1")

            cronJobMock = sandbox.mock(cronJob)
            cronJobMock.expects("CronJob").once().withArgs(config.checker.clearOldCronJobPattern).returns({})
            cronJobMock.expects("CronJob").once().withArgs(config.checker.handlePendingsCronJobPattern).throws(ex)

            error = undefined

            try
                _checker = new checker.Checker(config.checker)
            catch ex
                error = ex

            expect(error).to.not.be.undefined
            expect(error.message).to.include(ex.message)

            cronJobMock.verify()

            done()

        it 'создание объекта с ошибкой (1) (BDD-style)', (done) ->

            ex = new Error("gsom!!!1")

            cronJobMock = sandbox.mock(cronJob)
            expectation2 = cronJobMock.expects("CronJob").once().withArgs(config.checker.clearOldCronJobPattern).returns({})
            expectation2 = cronJobMock.expects("CronJob").once().withArgs(config.checker.handlePendingsCronJobPattern).returns({})
            cronJobMock.expects("CronJob").once().withArgs(config.checker.handleFailedCronJobPattern).throws(ex)

            error = undefined

            try
                _checker = new checker.Checker(config.checker)
            catch ex
                error = ex

            expect(error).to.not.be.undefined
            expect(error.message).to.include(ex.message)

            cronJobMock.verify()

            done()
    
    xdescribe 'cronJobs', () ->

        beforeEach (done) ->
            
            done()
        
        afterEach (done) ->
            #this.clock.restore()
            done()
        
        it 'штатный вызов процедуры удаления старых документов-отправлений (реальный config)', (done) ->

            now = new Date()
            console.log 'real: ' + now, now.getFullYear(), now.getMonth(), now.getDate()
            fakeDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 01, 59, 59)
            console.log 'fake: ' + fakeDate

            this.clock = sandbox.useFakeTimers(fakeDate.getTime())
            
            _checker = new checker.Checker(config.checker)

            clearOldStub = sandbox.stub(_checker, "clearOld")
            sandbox.stub(_checker, "handlePendings")
            sandbox.stub(_checker, "handleFailed")

            self = this

            setTimeout (() ->

                console.log 'fake: ' + new Date()
                self.clock.restore()
                console.log 'real: ' + new Date()

                expect(clearOldStub.called).to.be.true

                done()
            ), 1200

            this.clock.tick(1200);
            #done()
        
        it 'штатный вызов задачи обработки подготовленных документов-отправлений (реальный config)', (done) ->

            fakeTimeInterval = 60 * 1000 + 1000
            
            this.clock = sandbox.useFakeTimers()

            _checker = new checker.Checker(config.checker)
            clearOldStub = sandbox.stub(_checker, "clearOld")
            handleFailedStub = sandbox.stub(_checker, "handleFailed")
            handlePendingsStub = sandbox.spy(_checker, "handlePendings")

            self = this
            setTimeout (() ->
                #self.clock.restore()        
                expect(handlePendingsStub.callCount).to.be.within(3, 4)
                #assert.strictEqual(handlePendingsStub.called, false, "handlePendingsJob not called")
                self.clock.restore()
                done()
            ), fakeTimeInterval
        
            this.clock.tick(fakeTimeInterval + 10);

        it 'штатный вызов задачи обработки сбойных документов-отправлений (реальный config)', (done) ->
            
            fakeTimeInterval = 11 * 60 * 1000 + 1000

            this.clock = sandbox.useFakeTimers()

            _checker = new checker.Checker(config.checker)
            clearOldPendingsStub = sandbox.stub(_checker, "clearOld")
            handleFailedStub = sandbox.stub(_checker, "handleFailed")
            handlePendingsStub = sandbox.spy(_checker, "handlePendings")

            self = this
            setTimeout (() ->
                #expect(handleFailedStub.callCount).to.be.within(3, 4)
                expect(handleFailedStub.called).to.be.true
                self.clock.restore()
                done()
            ), fakeTimeInterval

            this.clock.tick(fakeTimeInterval + 10);            

    xdescribe 'clearOld', () ->

        _checker = {}

        beforeEach (done) ->
            _checker = mockChecker(sandbox)
            insertStubEmails collections.emails, () ->
                done()
        
        it 'нормальная работа процедуры (BDD-style)', (done) ->

            numberOfDocs = 2
            removeOldStub = sandbox.stub(dbEmailService, "removeOld").yields(null, numberOfDocs)
            logSpy = sandbox.spy(logStub, "info")
            
            _checker.clearOld()

            expect(removeOldStub.called).to.be.true
            expect(logSpy.called).to.be.true
            done()
        
        it 'нормальная работа процедуры (integration-style)', (done) ->

            msecInMonth = 31*24*60*60*1000
            numberOfOldDocs = (stubEmails.filter (item) ->
                #console.log 'it:', new Date(), "|||", item.dateCreated, "|||", new Date().getTime() - item.dateCreated.getTime() >= msecInMonth
                return new Date().getTime() - item.dateCreated.getTime() >= msecInMonth).length
            
            _checker.clearOld (err, result) ->

                expect(err).to.be.null
                expect(numberOfOldDocs).to.be.eql result

                collections.emails.findAsArray {}, {w: 0}, (err, docs) ->
                    expect(err).to.be.null
                    expect(docs?).to.be.true
                    expect(docs.length).to.be.eql stubEmails.length - numberOfOldDocs
                    done()

    xdescribe 'handlePendings', () ->

        _checker = {}

        beforeEach (done) ->
            _checker = mockChecker(sandbox)
            insertStubEmails collections.emails, () ->
                done()

        it 'нормальная работа процедуры', (done) ->

            pendings = (email for email in stubEmails when email.status == emailStatus.PENDING)
            resultStub = {128719837891}
            nextResultStub = {137826}
            getPendingListStub = sandbox.stub(dbEmailService, "getPendingList").yields(null, pendings)
            sendDocsStub = sandbox.stub(_checker, "sendDocs").yields(null, resultStub)
            markDocsStub = sandbox.stub(_checker, "markDocs").yields(null, nextResultStub)
            
            _checker.handlePendings (err, result) ->
                
                expect(err).to.be.null
                expect(result).to.be.eql nextResultStub
                expect(getPendingListStub.calledOnce).to.be.true
                expect(sendDocsStub.calledWithMatch(pendings)).to.be.true
                expect(markDocsStub.calledWithMatch(resultStub)).to.be.true
                done()

        it 'нормальная работа процедуры, документов не найдено', (done) ->

            pendings = []
            getPendingListStub = sandbox.stub(dbEmailService, "getPendingList").yields(null, pendings)

            _checker.handlePendings (err, result) ->

                expect(err).to.be.null
                expect(result).to.be.undefined
                expect(getPendingListStub.called).to.be.true
                done()
        
        it 'ошибка при получении списка', (done) ->

            error = { message: "error!!!11gsom"}
            sandbox.stub(dbEmailService, "getPendingList").yields(error)
            sendDocsSpy = sandbox.spy(_checker, "sendDocs")
            logSpy = sandbox.spy(logStub, "error")
            
            _checker.handlePendings (err, result) ->
                
                expect(err).to.be.eql error
                expect(result).to.be.undefined                
                expect(logSpy.calledOnce).to.be.true
                expect(sendDocsSpy.notCalled).to.be.true
                done()
        
        it 'ошибка при отправке списка писем', (done) ->

            pendings = (email for email in stubEmails when email.status == emailStatus.PENDING)
            error = { message: "error!!!11gsom"}
            sandbox.stub(dbEmailService, "getPendingList").yields(null, pendings)
            sandbox.stub(_checker, "sendDocs").yields(error)
            markdDocsSpy = sandbox.spy(_checker, "markDocs")
            logSpy = sandbox.spy(logStub, "error")

            _checker.handlePendings (err, result) ->

                expect(err).to.be.eql error
                expect(result).to.be.undefined
                expect(logSpy.calledOnce).to.be.true
                expect(markdDocsSpy.notCalled).to.be.true
                done()

        it 'ошибка при маркировке списков писем', (done) ->

            pendings = (email for email in stubEmails when email.status == emailStatus.PENDING)
            resultStub = {128719837891}
            error = { message: "error!!!11gsom"}
            sandbox.stub(dbEmailService, "getPendingList").yields(null, pendings)
            sandbox.stub(_checker, "sendDocs").yields(null, resultStub)
            sandbox.stub(_checker, "markDocs").yields(error)

            _checker.handlePendings (err, result) ->

                expect(err).to.be.eql error
                expect(result).to.be.undefined
                done()

    xdescribe 'handleFailed', () ->

        _checker = {}

        beforeEach (done) ->
            _checker = mockChecker(sandbox)
            insertStubEmails collections.emails, () ->
                done()

        it 'нормальная работа процедуры', (done) ->

            failed = (email for email in stubEmails when email.status == emailStatus.ERROR)
            resultStub = {128719837891}
            nextResultStub = {137826}
            getFailedListStub = sandbox.stub(dbEmailService, "getFailedList").yields(null, failed)
            sendDocsStub = sandbox.stub(_checker, "sendDocs").yields(null, resultStub)
            markDocsStub = sandbox.stub(_checker, "markDocs").yields(null, nextResultStub)

            _checker.handleFailed (err, result) ->
                expect(err).to.be.null
                expect(result).to.be.eql nextResultStub
                expect(getFailedListStub.calledOnce).to.be.true
                expect(sendDocsStub.calledWithMatch(failed)).to.be.true
                expect(markDocsStub.calledWithMatch(resultStub)).to.be.true
                done()

        it 'нормальная работа процедуры, документов не найдено', (done) ->

            pendings = []
            getFailedListStub = sandbox.stub(dbEmailService, "getFailedList").yields(null, pendings)

            _checker.handleFailed (err, result) ->

                expect(err).to.be.null
                expect(result).to.be.undefined
                expect(getFailedListStub.called).to.be.true
                done()
        
        it 'ошибка при получении списка', (done) ->

            error = { message: "error!!!11gsom"}
            sandbox.stub(dbEmailService, "getFailedList").yields(error)
            sendDocsSpy = sandbox.spy(_checker, "sendDocs")
            logSpy = sandbox.spy(logStub, "error")

            _checker.handleFailed (err, result) ->

                expect(err).to.be.eql error
                expect(result).to.be.undefined
                expect(logSpy.calledOnce).to.be.true
                expect(sendDocsSpy.notCalled).to.be.true
                done()

        it 'ошибка при отправке списка писем', (done) ->

            failed = (email for email in stubEmails when email.status == emailStatus.ERROR)
            error = { message: "error!!!11gsom"}
            sandbox.stub(dbEmailService, "getFailedList").yields(null, failed)
            sandbox.stub(_checker, "sendDocs").yields(error)
            markdDocsSpy = sandbox.spy(_checker, "markDocs")
            logSpy = sandbox.spy(logStub, "error")

            _checker.handleFailed (err, result) ->

                expect(err).to.be.eql error
                expect(result).to.be.undefined
                expect(logSpy.calledOnce).to.be.true
                expect(markdDocsSpy.notCalled).to.be.true
                done()

        it 'ошибка при маркировке списков писем', (done) ->

            failed = (email for email in stubEmails when email.status == emailStatus.ERROR)
            resultStub = {128719837891}
            error = { message: "error!!!11gsom"}
            sandbox.stub(dbEmailService, "getFailedList").yields(null, failed)
            sandbox.stub(_checker, "sendDocs").yields(null, resultStub)
            sandbox.stub(_checker, "markDocs").yields(error)

            _checker.handleFailed (err, result) ->

                expect(err).to.be.eql error
                expect(result).to.be.undefined
                done()
        
    xdescribe 'sendDocs', () ->

        _checker = {}

        beforeEach (done) ->
            _checker = mockChecker(sandbox)
            insertStubEmails collections.emails, () ->
                done()

        it 'нормальная работа', (done) ->

            toSend = (email for email in stubEmails when email.status != emailStatus.SENT)
            
            mailerStub = {
                id: "mailerStub"
                send: (doc, callback) ->
            }

            errorStub = { message: "error!!!11gsom"}
            
            responseStub = {
                message: "ta-da-dammm!"
                messageId: 37784216
                failedRecipients: ["someRecipient"]
            }

            #stubbibg a mailer constructor to get mailerStub
            sandbox.stub(Mailer, "Mailer").returns mailerStub

            mock = sandbox.mock(mailerStub)
            sendExps1 = mock.expects("send").withArgs(toSend[0]).yields(null, responseStub)
            sendExps2 = mock.expects("send").withArgs(toSend[1]).yields(errorStub)

            _checker.sendDocs toSend, (err, result) ->

                expect(err).to.be.null
                expect(result?).to.be.true
                expect(result.failed[0]).to.be.eql toSend[1]
                expect(result.errorList[0]).to.be.eql errorStub
                expect(result.sent[0]).to.be.eql toSend[0]
                expect(result.responseList[0]).to.be.eql responseStub
                
                sandbox.verify()
                done()

        it 'пустой или неопределенный список писем', (done) ->

            _checker.sendDocs null, (err, result) ->

                expect(err).to.be.eql RES.INVALID_ARGUMENTS
                expect(result).to.be.undefined
                done()

    xdescribe 'markDocs', () ->

        responseStub = {} 

        _checker = {}

        beforeEach (done) ->
            _checker = mockChecker(sandbox)
            insertStubEmails collections.emails, () ->
                responseStub = {
                    message: "ta-da-dammm!"
                    messageId: 37784216
                    failedRecipients: ["someRecipient"]
                }
                done()

        it 'без сбоев при отправлении', (done) ->
            
            responseStub.failedRecipients = undefined
            
            sendDocsResultStub = {
                sent: [stubEmails[0], stubEmails[2]]
                responseList: [ responseStub, responseStub]
            }

            markAsFailedSpy = sandbox.spy(dbEmailService, "markAsFailed")
            sandbox.stub(dbEmailService, "markAsSent").yields(null, sendDocsResultStub.sent.length)
            logSpy = sandbox.spy(logStub, "error")

            _checker.markDocs sendDocsResultStub, (err, sendDocsResultStub) ->

                expect(err).to.be.null
                expect(markAsFailedSpy.notCalled).to.be.true
                expect(sendDocsResultStub.failedMarked).to.be.undefined
                expect(sendDocsResultStub.sentMarked).to.be.eql sendDocsResultStub.sent.length
                # log не должен выводить ничего 
                expect(logSpy.notCalled).to.be.true
                done()
        
        it 'есть сбои при отправлении (+ сбои при отправлениях копий)', (done) ->

            sendDocsResultStub = {
                failed: [stubEmails[0], stubEmails[2]]
                sent: [stubEmails[1]]
                responseList: [ responseStub ]
            }            
            
            sandbox.stub(dbEmailService, "markAsFailed").yields(null, sendDocsResultStub.failed.length)
            sandbox.stub(dbEmailService, "markAsSent").yields(null, sendDocsResultStub.sent.length)
            logSpy = sandbox.spy(logStub, "error")

            _checker.markDocs sendDocsResultStub, (err, sendDocsResultStub) ->
                
                expect(err).to.be.null
                expect(sendDocsResultStub.failedMarked).to.be.eql sendDocsResultStub.failed.length
                expect(sendDocsResultStub.sentMarked).to.be.eql sendDocsResultStub.sent.length
                # log должен вывести: 
                # одно служебное сообщение для оповещения + 
                # + сообщения для каждого полностью сбойного отправления + 
                # + сообщения для каждого получателя внутри "писем" (в случае когда поля to, cc, bcc -- массивы),отправление которым завершилось ошибкой  
                expect(logSpy.callCount).to.be.eql 1 + sendDocsResultStub.failed.length + responseStub.failedRecipients.length
                done()

        it 'сбои при маркировке документов в базе', (done) ->

            sendDocsResultStub = {
                failed: [stubEmails[0], stubEmails[2]]
                sent: [stubEmails[1]]
            }
            
            numberOfFailedDocsMarked = 1
            sandbox.stub(dbEmailService, "markAsFailed").yields(RES.UPDATE_NOT_ALL_DOCUMENTS_INVOLVED, numberOfFailedDocsMarked)
            sandbox.stub(dbEmailService, "markAsSent").yields(RES.INTERNAL_ERROR)
            logSpy = sandbox.spy(logStub, "error")

            _checker.markDocs sendDocsResultStub, (err, sendDocsResultStub) ->

                expect(err).to.be.null
                expect(sendDocsResultStub.failedMarked).to.be.eql numberOfFailedDocsMarked
                expect(sendDocsResultStub.sentMarked).to.be.eql 0
                # log должен вывести: 
                # одно служебное сообщение для оповещения + 
                # два сообщения об ошибках при маркировке +
                # + сообщения для каждого полностью сбойного отправления + 
                expect(logSpy.callCount).to.be.eql  1 + 2 + sendDocsResultStub.failed.length
                done()
       
