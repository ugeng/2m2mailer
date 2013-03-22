#process.env.NODE_ENV = 'test'
config = require '../../src/config'
checker = require('../../src/logic/checker')

#dependencies
cronJob = require 'cron'
mailer = require '../../src/services/s-email-transport'
MailerLog = mailer.log
dbEmailService = require '../../src/services/s-email'
mailDbServiceLog = dbEmailService.log
When = require 'when'

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

describe 'Checker', ->

    sandbox = {}

    before (done) ->
        # перенаправляем вывод штатных логов в заглушки, чтобы не засорять консоль
        console.log 'running in %s environment.', process.env.NODE_ENV
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

        it 'создание объекта с ошибкой (2) (BDD-style)', (done) ->

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

        it 'создание объекта с ошибкой (3) (BDD-style)', (done) ->

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
            fakeDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 1, 59, 59)
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

    describe 'clearOld', () ->

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

    describe 'handleJob', () ->

        _checker = {}

        beforeEach (done) ->
            _checker = mockChecker(sandbox)
            insertStubEmails collections.emails, () ->
                done()

        it 'нормальная работа процедуры', (done) ->

            pendings = (email for email in stubEmails when email.status == emailStatus.PENDING)
            sendDocsResultStub = [{doc: {}, success: true}, {doc: {}, success: false}, {doc: {}, success: true}, {doc: {}, success: true}, {doc: {}, success: false}]

            getPendingListStub = sandbox.stub(dbEmailService, "getPendingList").yields(null, pendings)
            sendDocsStub = sandbox.stub(_checker, "sendDocs").returns(sendDocsResultStub)
            forSuccessfullSpy = sandbox.stub(_checker, "forSuccessfull").returns({})
            forFailedSpy = sandbox.stub(_checker, "forFailed").returns({})
            
            _checker.handleJob 'pendingJob', getPendingListStub, (err, result) ->
                
                expect(err).is.null
                expect(result).is.eql sendDocsResultStub
                expect(result).is.eql sendDocsResultStub
                expect(getPendingListStub.calledOnce).is.true
                expect(sendDocsStub.calledWithMatch(pendings)).is.true
                success = (result.doc for result in sendDocsResultStub when result.success == true)
                failed = (result.doc for result in sendDocsResultStub when result.success == false)
                expect(forSuccessfullSpy.calledWithMatch(success)).is.true
                expect(forFailedSpy.calledWithMatch(failed)).is.true
                done()

        it 'нормальная работа процедуры, документов не найдено', (done) ->

            pendings = []
            getPendingListStub = sandbox.stub(dbEmailService, "getPendingList").yields(null, pendings)

            _checker.handleJob 'pendingJob', getPendingListStub, (err, result) ->

                expect(err).is.null
                expect(result).is.undefined
                expect(getPendingListStub.called).is.true
                done()
        
        it 'ошибка при получении списка', (done) ->

            error = { message: "error!!!11gsom"}
            getPendingListStub = sandbox.stub(dbEmailService, "getPendingList").yields(error)
            sendDocsSpy = sandbox.spy(_checker, "sendDocs")
            logSpy = sandbox.spy(logStub, "error")

            _checker.handleJob 'pendingJob', getPendingListStub, (err, result) ->
                
                expect(err).is.eql error
                expect(result).is.undefined                
                expect(logSpy.calledOnce).is.true
                expect(sendDocsSpy.notCalled).is.true
                done()
        
    describe 'sendDocs', () ->

        _checker = undefined

        before (done) ->
            @sandbox = sinon.sandbox.create()
            @checker = mockChecker(@sandbox)
            @checkerMock = @sandbox.mock(@checker)
            insertStubEmails collections.emails, () ->
                done()

        describe 'Нормальная работа', ->

            before (done) ->

                @toSend = (email for email in stubEmails when email.status != emailStatus.SENT)
    
                defers = []
                stubs = []
                for doc in @toSend
                    defer = When.defer()
                    defers.push defer
                    @checkerMock.expects("sendDoc").withArgs(doc).returns(defer.promise)
    
                When @checker.sendDocs(@toSend), (results) =>
                    @results = results
                    done()                    

                #resolving defers
                for defer, i in defers
                    defer.resolve({doc: {value: 'someVal'}, success: true})

            it 'Метод sendDoc должен вызываться для каждого документа', ->
                @checkerMock.verify()
                
            it 'Должна вызываться процедура обратного вызова для успешных promises', ->
                expect(@results?).is.true
            
            it 'Количество успешных promises должно совпадать с количеством исходных документов', ->
                expect(@results.length).is.eql @toSend.length

        it 'пустой или неопределенный список писем', (done) ->
            
            result = @checker.sendDocs null
            expect(result).is.eql RES.INVALID_ARGUMENTS
            done()
    
    after (done) ->
        @sandbox.restore()
        done()

describe 'sendDoc', () ->
    
    before (done) ->
        done()
    
    describe 'Нормальная работа', ->
        
        before (done) ->
            @doc = {value: 'someValue'}
            
            @sandbox = sinon.sandbox.create()
            
            @checker = mockChecker(@sandbox)
            
            @mailerStub = {send: @sandbox.stub().yields(null, {ok: true})}
            @mailerMock = @sandbox.mock(mailer)
            @mailerMock.expects("Mailer").once().withArgs(config.mailTransportType, config.mailTransportConfig).returns(@mailerStub)

            @deferStub = {resolve: @sandbox.spy()}
            @deferMock = @sandbox.mock(When)
            @deferMock.expects("defer").once().returns(@deferStub)            

            @result = @checker.sendDoc @doc

            done()

        it 'Должен возвращать непустой результат', ->
            expect(@result).is.not.false
            expect(@result).is.not.null
            
        it 'Должен конструировать объект-транспорт с верными параметрами', ->
            @mailerMock.verify()

        it 'Должен вызывать транспортный метод send с документом в качестве первого аргумента', ->
            expect(@mailerStub.send.lastCall.args[0]).is.eql @doc

        it 'Должен конструировать объект-обещание', ->
            @deferMock.verify()            

        it 'Должен разрешать promise с верным значением', ->
            expect(@deferStub.resolve.lastCall.args[0]).is.eql {doc: @doc, success: true}
            
        after (done) ->
            @sandbox.restore()
            done()

    describe 'Сбой', ->

        before (done) ->
            @doc = {value: 'someValue'}

            @sandbox = sinon.sandbox.create()

            @checker = mockChecker(@sandbox)

            @mailerStub = {send: @sandbox.stub().yields(@err = {message: "gsom!!11"})}
            @mailerMock = @sandbox.mock(mailer)
            @mailerMock.expects("Mailer").once().withArgs(config.mailTransportType, config.mailTransportConfig).returns(@mailerStub)

            @deferStub = {resolve: @sandbox.spy()}
            @deferMock = @sandbox.mock(When)
            @deferMock.expects("defer").once().returns(@deferStub)

            @logSpy = @sandbox.spy(logStub, "error")
            
            @result = @checker.sendDoc @doc

            done()

        it 'Должен возвращать непустой результат', ->
            expect(@result).is.not.false
            expect(@result).is.not.null

        it 'Должен конструировать объект-транспорт с верными параметрами', ->
            @mailerMock.verify()

        it 'Должен вызывать транспортный метод send с документом в качестве первого аргумента', ->
            expect(@mailerStub.send.lastCall.args[0]).is.eql @doc

        it 'Должен конструировать объект-обещание', ->
            @deferMock.verify()

        it 'Должен документировать сообщение об ошибке', ->
            expect(@err in @logSpy.lastCall.args).is.true                          

        it 'Должен разрешать promise с верным значением', ->
            expect(@deferStub.resolve.lastCall.args[0]).is.eql {doc: @doc, success: false}

        after (done) ->
            @sandbox.restore()
            done()
