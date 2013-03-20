process.env.NODE_ENV = 'test'
db = require '../../src/infra/db'
RES = require '../../src/infra/RES'
config = require '../../src/config'
cols = require '../../src/infra/db/collections'
emailStatus = require '../../src/infra/email/email-status-enum'
collections = require '../../src/infra/db/collections'
emailService = require '../../src/services/s-email'

Binary = require("mongodb").Binary  

expect = require('chai').expect
sinon = require('sinon')

#-----------------------------
# test helpers
logStub = require('../../src/infra/log').logStub

describe 'emailService', ->

    sandbox = {}
    stubEmails = {}

    data = []
    for i in [0...900]
        data[i] = i

    buffer = new Buffer(data)

    attachment = { fileName: 'file', content: new Binary(buffer) }

    attachments = [ attachment ]

    before (done) ->
        emailService.setLog(logStub)
        done()
    
    after (done) ->
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
    
    describe 'getPendingList', () ->

        beforeEach (done) ->

           
            stubEmails =
                [ { subject: 'reg', body: 'hello', from: 'sender', to: 'address1@server.org', cc: ['addr11@server.org', 'addr12@server.org'], bcc: ['addr13@server.org', 'addr14@server.org'], status: emailStatus.PENDING, dateCreated: new Date(), attachments: attachments },
                    { subject: 'reg', body: 'hello', from: 'sender', to: 'address2@server.org', cc: ['addr21@server.org', 'addr22@server.org'], bcc: ['addr23@server.org', 'addr24@server.org'], status: emailStatus.SENT, dateCreated: new Date(), attachments: attachments }
                    { subject: 'reg', body: 'hello', from: 'sender', to: 'address3@server.org', cc: ['addr31@server.org', 'addr32@server.org'], bcc: ['addr33@server.org', 'addr34@server.org'], status: emailStatus.PENDING, dateCreated: new Date(), attachments: attachments }
                ]
            cols.emails.remove () ->
                cols.emails.insert stubEmails, {w: 1}, () ->
                    done()
    
        afterEach (done) ->
            done()


        it 'получение списка отправки при наличии записей в базе', (done) ->

            pendings = stubEmails.filter (item) -> return item.status == emailStatus.PENDING
                
            #chain stub в случае использования метода find, который возвращает курсор и это курсор необходимо преобразовывать ToArray 
            #cursorStub = { toArray: sandbox.stub().yields(null, stubEmails) }
            #findStub = sandbox.stub(cols.emails, "find").returns(cursorStub)
            
            #findStub = sandbox.stub(cols.emails, "findAsArray").yields(null, stubEmails)


            emailService.getPendingList (err, list) ->
                
                expect(err).to.be.null
                expect(list).to.be.eql(pendings)
                done()

        it 'обработка ошибки при получении списка', (done) ->

            findStub = sandbox.stub(cols.emails, "findAsArray").yields(err = {})

            emailService.getPendingList (err, list) ->

                expect(err).to.not.be.null
                expect(list).to.be.undefined
                expect(err).to.be.eql(RES.INTERNAL_ERROR)
                done()

    describe 'getSentList', () ->

        beforeEach (done) ->

            stubEmails =
                [ { subject: 'reg', body: 'hello', from: 'sender', to: 'address1@server.org', cc: ['addr11@server.org', 'addr12@server.org'], bcc: ['addr13@server.org', 'addr14@server.org'], status: emailStatus.PENDING, dateCreated: new Date(), attachments: attachments },
                    { subject: 'reg', body: 'hello', from: 'sender', to: 'address2@server.org', cc: ['addr21@server.org', 'addr22@server.org'], bcc: ['addr23@server.org', 'addr24@server.org'], status: emailStatus.ERROR, dateCreated: new Date(), attachments: attachments }
                    { subject: 'reg', body: 'hello', from: 'sender', to: 'address3@server.org', cc: ['addr31@server.org', 'addr32@server.org'], bcc: ['addr33@server.org', 'addr34@server.org'], status: emailStatus.PENDING, dateCreated: new Date(), attachments: attachments }
                ]
            cols.emails.remove () ->
                cols.emails.insert stubEmails, {w: 1}, () ->
                    done()

        afterEach (done) ->
            done()        
        
        it 'получение списка отправленных сообщений при наличии записей в базе', (done) ->

            sent = stubEmails.filter (item) -> return item.status == emailStatus.SENT
            
            emailService.getSentList (err, list) ->

                expect(err).to.be.null
                expect(list).to.be.eql(sent)
                done()

        it 'обработка ошибки при получении списка', (done) ->

            findStub = sandbox.stub(cols.emails, "findAsArray").yields(err = {})

            emailService.getSentList (err, list) ->

                expect(err).to.not.be.null
                expect(list).to.be.undefined
                expect(err).to.be.eql(RES.INTERNAL_ERROR)
                done()

    describe 'geFailedList', () ->

        beforeEach (done) ->

            stubEmails =
                [ { subject: 'reg', body: 'hello', from: 'sender', to: 'address1@server.org', cc: ['addr11@server.org', 'addr12@server.org'], bcc: ['addr13@server.org', 'addr14@server.org'], status: emailStatus.ERROR, dateCreated: new Date(), attachments: attachments },
                    { subject: 'reg', body: 'hello', from: 'sender', to: 'address2@server.org', cc: ['addr21@server.org', 'addr22@server.org'], bcc: ['addr23@server.org', 'addr24@server.org'], status: emailStatus.SENT, dateCreated: new Date(), attachments: attachments }
                    { subject: 'reg', body: 'hello', from: 'sender', to: 'address3@server.org', cc: ['addr31@server.org', 'addr32@server.org'], bcc: ['addr33@server.org', 'addr34@server.org'], status: emailStatus.ERROR, dateCreated: new Date(), attachments: attachments }
                ]
            cols.emails.remove () ->
                cols.emails.insert stubEmails, {w: 1}, () ->
                    done()

        afterEach (done) ->
            done()

        it 'получение списка сообщений, оптравленных с ошибкой', (done) ->
           
            failedList = stubEmails.filter (item) -> return item.status == emailStatus.ERROR
                
            emailService.getFailedList (err, list) ->

                expect(err).to.be.null
                expect(list).to.be.eql(failedList)
                done()

        it 'обработка ошибки при получении списка', (done) ->

            findStub = sandbox.stub(cols.emails, "findAsArray").yields(err = {})

            emailService.getFailedList (err, list) ->

                expect(err).to.not.be.null
                expect(list).to.be.undefined
                expect(err).to.be.eql(RES.INTERNAL_ERROR)
                done()

    describe 'markAsSent', () ->

        beforeEach (done) ->

            stubEmails =
                [ { subject: 'reg', body: 'hello', from: 'sender', to: 'address1@server.org', cc: ['addr11@server.org', 'addr12@server.org'], bcc: ['addr13@server.org', 'addr14@server.org'], status: emailStatus.PENDING, dateCreated: new Date(), attachments: attachments },
                    { subject: 'reg', body: 'hello', from: 'sender', to: 'address2@server.org', cc: ['addr21@server.org', 'addr22@server.org'], bcc: ['addr23@server.org', 'addr24@server.org'], status: emailStatus.ERROR, dateCreated: new Date(), attachments: attachments }
                    { subject: 'reg', body: 'hello', from: 'sender', to: 'address3@server.org', cc: ['addr31@server.org', 'addr32@server.org'], bcc: ['addr33@server.org', 'addr34@server.org'], status: emailStatus.PENDING, dateCreated: new Date(), attachments: attachments }
                ]
            cols.emails.remove () ->
                cols.emails.insert stubEmails, {w: 1}, () ->
                    done()

        afterEach (done) ->
            done()        
        
        it 'смена статуса для отправленных сообщений', (done) ->

            pendings = (email for email in stubEmails when email.status == emailStatus.PENDING)
            for item in pendings
                item.status = emailStatus.SENT
            
            emailService.markAsSent pendings, (err, numberOfDocs) ->
                
                expect(err).to.be.null
                expect(numberOfDocs).to.be.equal pendings.length
                
                emailService.getSentList (err, list) ->
                   
                    expect(err).to.be.null
                    expect(list.length).to.be.eql numberOfDocs
                    
                    for item, idx in list
                        expect(item.dateSent).to.not.be.undefined
                        expect(item.dateSent).to.not.be.null
                        p = (email for email in pendings when email._id == item._id)
                        expect(p).is.not.null
                        expect(p.length).is.eql 1

                    done()

        it 'не все документы изменены при смене статуса отправленных сообщений', (done) ->

            pendings = (email for email in stubEmails when email.status == emailStatus.PENDING)
            for item in pendings
                item.status = emailStatus.SENT

            numberOfDocsMarked = 1
                
            findStub = sandbox.stub(cols.emails, "update").yields(null, numberOfDocsMarked)
                
            emailService.markAsSent pendings, (err, numberOfDocs) ->

                expect(err).to.equal(RES.UPDATE_NOT_ALL_DOCUMENTS_INVOLVED)
                expect(numberOfDocs).to.be.eql numberOfDocsMarked
                done()

        it 'ошибка при смене статуса отправленных сообщений', (done) ->

            pendings = (email for email in stubEmails when email.status == emailStatus.PENDING)
            for item in pendings
                item.status = emailStatus.SENT

            findStub = sandbox.stub(cols.emails, "update").yields(err = {})

            emailService.markAsSent pendings, (err, numberOfDocs) ->

                expect(err).to.equal(RES.INTERNAL_ERROR)
                expect(numberOfDocs).to.be.undefined
                done()

    describe 'markAsError', () ->

        beforeEach (done) ->

            stubEmails =
                [ { subject: 'reg', body: 'hello', from: 'sender', to: 'address1@server.org', cc: ['addr11@server.org', 'addr12@server.org'], bcc: ['addr13@server.org', 'addr14@server.org'], status: emailStatus.PENDING, dateCreated: new Date(), attempts: 1, attachments: attachments },
                    { subject: 'reg', body: 'hello', from: 'sender', to: 'address2@server.org', cc: ['addr21@server.org', 'addr22@server.org'], bcc: ['addr23@server.org', 'addr24@server.org'], status: emailStatus.SENT, dateCreated: new Date(), attachments: attachments }
                    { subject: 'reg', body: 'hello', from: 'sender', to: 'address3@server.org', cc: ['addr31@server.org', 'addr32@server.org'], bcc: ['addr33@server.org', 'addr34@server.org'], status: emailStatus.PENDING, dateCreated: new Date(), attachments: attachments }
                ]
            cols.emails.remove () ->
                cols.emails.insert stubEmails, {w: 1}, () ->
                    done()

        afterEach (done) ->
            done()

        it 'смена статуса отправленных сообщений', (done) ->

            failedList = (email for email in stubEmails when email.status == emailStatus.PENDING)
            for item in failedList
                item.status = emailStatus.ERROR
                if item.attempts? then item.attempts++
                else item.attempts = 1
                
            emailService.markAsFailed failedList, (err, numberOfDocs) ->

                expect(err).to.be.null
                expect(numberOfDocs).to.be.equal failedList.length

                emailService.getFailedList (err, list) ->
                    expect(err).to.be.null
                    expect(list).to.be.eql(failedList)
                    done()

        it 'не все документы изменены при смене статуса отправленных сообщений', (done) ->

            failedList = (email for email in stubEmails when email.status == emailStatus.PENDING)
            for item in failedList
                item.status = emailStatus.ERROR

            numberOfDocsMarked = 1
                
            findStub = sandbox.stub(cols.emails, "update").yields(null, numberOfDocsMarked)

            emailService.markAsFailed failedList, (err, numberOfDocs) ->

                expect(err).to.equal(RES.UPDATE_NOT_ALL_DOCUMENTS_INVOLVED)
                expect(numberOfDocs).to.be.eql numberOfDocsMarked
                done()

        it 'ошибка при смене статуса отправленных сообщений', (done) ->

            failedList = (email for email in stubEmails when email.status == emailStatus.PENDING)
            for item in failedList
                item.status = emailStatus.ERROR

            findStub = sandbox.stub(cols.emails, "update").yields(err = {})

            emailService.markAsFailed failedList, (err, numberOfDocs) ->

                expect(err).to.equal(RES.INTERNAL_ERROR)
                expect(numberOfDocs).to.be.undefined
                done()

    describe 'removeOld', () ->

        beforeEach (done) ->

            currentDate = new Date()
            oldEmailsDate = new Date()
            notTooOldEmailsDate = new Date()
        
            oldEmailsDate.setMonth(currentDate.getMonth() - 1)
            notTooOldEmailsDate.setDate(currentDate.getDate()-11)
    
            stubEmails =
            [ { subject: 'reg', body: 'hello', from: 'sender', to: 'address1@server.org', cc: ['addr11@server.org', 'addr12@server.org'], bcc: ['addr13@server.org', 'addr14@server.org'], status: emailStatus.ERROR, dateCreated: oldEmailsDate, attempts: 1, attachments: attachments },
                { subject: 'reg', body: 'hello', from: 'sender', to: 'address2@server.org', cc: ['addr21@server.org', 'addr22@server.org'], bcc: ['addr23@server.org', 'addr24@server.org'], status: emailStatus.ERROR, dateCreated: notTooOldEmailsDate, attachments: attachments }
                { subject: 'reg', body: 'hello', from: 'sender', to: 'address3@server.org', cc: ['addr31@server.org', 'addr32@server.org'], bcc: ['addr33@server.org', 'addr34@server.org'], status: emailStatus.ERROR, dateCreated: oldEmailsDate, attachments: attachments }
            ]
       
            cols.emails.remove () ->
                cols.emails.insert stubEmails, {w: 1}, () ->
                    done()

        afterEach (done) ->
            done()

        it 'нормальное удаление', (done) ->

            emailService.removeOld (err, numberOfDocs) ->

                expect(err).to.be.null
                expect(numberOfDocs).to.equal(2)
                
                #проверка
                emailService.getFailedList (err, docs) ->
                    expect(err).to.be.null
                    expect(docs.length).to.equal(1)
                    expect(docs[0]).to.eql stubEmails[1]
                    done()

        it 'удаление c ошибкой', (done) ->

            findStub = sandbox.stub(cols.emails, "remove").yields(err = {})
            
            emailService.removeOld (err, numberOfDocs) ->

                expect(err).to.be.equal RES.INTERNAL_ERROR 
                expect(numberOfDocs).to.be.undefined
                done()

