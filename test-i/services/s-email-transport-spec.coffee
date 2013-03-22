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

    sandbox = undefined
    
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
        
        it 'нормальное отправление одного письма (integration-style)', (done) ->

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