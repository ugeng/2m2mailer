nodemailer = require "nodemailer"
underscore = require("underscore")
Binary = require("mongodb").Binary

RES = require "../../src/infra/RES"
config = require "../../src/config"
Mailer = require "../../src/services/s-email-transport"
emailStatus = require '../../src/infra/email/email-status-enum'


expect = require('chai').expect
sinon = require('sinon')

describe 'emailTransportService', ->

    sandbox = {}

    before (done) ->
        done()
    after (done) ->
        done()

    beforeEach (done) ->
        sandbox = sinon.sandbox.create()
        done()

    afterEach (done) ->
        sandbox.restore done
        done()

    describe 'Mailer.constructor', () ->
        
        transportStub = {
            sendMail: (message, callback) ->
        }
        
        it 'создание объекта (реальная конфигурация)', (done) ->

            spy = sandbox.spy(nodemailer, "createTransport")
            
            mailer = new Mailer.Mailer config.mailTransportType, config.mailTransportConfig

            expect(spy.calledWithExactly(config.mailTransportType, config.mailTransportConfig)).to.be.true
            expect(mailer.transport).to.not.undefined
    
            done()

        it 'создание объекта (BDD-style)', (done) ->

            createTransportStub = sandbox.stub(nodemailer, "createTransport").returns(transportStub)

            mailer = new Mailer.Mailer config.mailTransportType, config.mailTransportConfig

            expect(mailer.transport).to.be.eql transportStub

            done()
            
    describe 'Mailer.send', () ->

        transportStub = {
            sendMail: (message, callback) ->
        }

        email = {
            subject: 'subj'
            body: '<html>Hello!</html>'
            to: 'dev1979@inbox.ru; gsom'
            cc: ['addr11@server.org', 'addr12@server.org']
            bcc: ['addr13@server.org', 'addr14@server.org']
            status: emailStatus.PENDING
            dateCreated: new Date()
        }
        
        it 'нормальное отправление одного письма (BDD-style)', (done) ->

            response = {msg: '!!!!111gsom'}
            
            createTransportStub = sandbox.stub(nodemailer, "createTransport").returns(transportStub)
            sendMailStub = sandbox.stub(transportStub, "sendMail").yields(null, response)
            
            mailer = new Mailer.Mailer config.mailTransportType, config.mailTransportConfig
            
            mailer.send email, (err, result) ->
                
                expect(err).to.be.null
                expect(result).to.be.eql response
                expect(mailer.messageData.to).to.be.eql email.to
                expect(mailer.messageData.cc).to.be.eql email.cc
                expect(mailer.messageData.bcc).to.be.eql email.bcc
                expect(mailer.messageData.subject).to.be.eql email.subject
                expect(mailer.messageData.html).to.be.eql email.body
                expect(sendMailStub.calledWithMatch(mailer.messageData)).to.be.true
                
                done()

        it 'нормальное отправление одного письма с двоичным вложением (BDD-style)', (done) ->

            response = {msg: '!!!!111gsom'}
            
            data = []
            for i in [0...100]
                data[i] = i

            buffer = new Buffer(data)
            
            attachment = {
                fileName: 'file'
                content: new Binary(buffer)
            }
            
            email.attachments = []
            email.attachments.push(attachment)

            createTransportStub = sandbox.stub(nodemailer, "createTransport").returns(transportStub)
            sendMailStub = sandbox.stub(transportStub, "sendMail").yields(null, response)

            mailer = new Mailer.Mailer config.mailTransportType, config.mailTransportConfig

            setupAttachmentsSpy = sandbox.spy(mailer, "setupAttachments")
            
            mailer.send email, (err, result) ->

                expect(err).to.be.null
                expect(result).to.be.eql response
                expect(setupAttachmentsSpy.calledWithExactly(email.attachments)).to.be.true
                expect(mailer.messageData.attachments).to.not.be.undefined
                expect(mailer.messageData.attachments).to.be.eql email.attachments
                expect(sendMailStub.calledWithMatch(mailer.messageData)).to.be.true
                done()

        it 'нормальное отправление одного письма с cid-вложением (BDD-style)', (done) ->

            response = {msg: '!!!!111gsom'}

            data = []
            for i in [0...100]
                data[i] = i

            buffer = new Buffer(data)

            attachment = {
                fileName: 'file'
                filePath: './somePath/'
                cid: 'cid112@2m2'
            }

            email.attachments = []
            email.attachments.push(attachment)

            createTransportStub = sandbox.stub(nodemailer, "createTransport").returns(transportStub)
            sendMailStub = sandbox.stub(transportStub, "sendMail").yields(null, response)

            mailer = new Mailer.Mailer config.mailTransportType, config.mailTransportConfig

            setupAttachmentsSpy = sandbox.spy(mailer, "setupAttachments")

            mailer.send email, (err, result) ->

                expect(err).to.be.null
                expect(result).to.be.eql response
                expect(setupAttachmentsSpy.calledWithExactly(email.attachments)).to.be.true
                expect(mailer.messageData.attachments).to.not.be.undefined
                expect(mailer.messageData.attachments[0].cid).to.be.eql email.attachments[0].cid
                expect(mailer.messageData.attachments[0].file).to.be.eql email.attachments[0].file
                expect(mailer.messageData.attachments[0].filePath).to.be.eql config.attachmentsBaseDirectory + email.attachments[0].filePath                
                expect(sendMailStub.calledWithMatch(mailer.messageData)).to.be.true
                done()
        
        xit 'нормальное отправление одного письма (integration-style)', (done) ->

            createTransportSpy = sandbox.spy(nodemailer, "createTransport")
            
            mailer = new Mailer.Mailer config.mailTransportType, config.mailTransportConfig

            transport = mailer.transport

            sendMailSpy = sandbox.spy(transport, "sendMail")

            mailer.send email, (err, result) ->

                expect(sendMailSpy.calledOnce).to.be.true
                expect(err).to.be.null
                expect(result).to.not.be.undefined
                expect(result).to.not.be.null
                expect(result.failedRecipients).to.be.eql([])

                done()