process.env.NODE_ENV = 'test'
MongoDb = require('mongodb').Db
config = require('../../../src/config')
db = require('../../../src/infra/db')

expect = require('chai').expect
ObjectID = require('mongodb').ObjectID
sinon = require('sinon')

#-----------------------------------------
# test helpers
#-----------------------------------------
# перенаправляем лог в заглушку, чтобы не засорять консоль
logStub = require('../../../src/infra/log').logStub

describe 'db', ->

    before (done) ->
        db.setLog(logStub)
        done()
    
    sandbox = {}

    beforeEach (done) ->
        sandbox = sinon.sandbox.create()
        done()

    afterEach (done) ->
        sandbox.restore()
        done()


    describe 'init', () ->
        
        it 'нормальная инициализация', (done) ->

            spy = sandbox.spy(MongoDb, "connect")

            db.init (err, db) ->
            
                expect(err).to.be.null
                expect(db).to.not. be.null
                expect(spy.calledWithMatch(config.db.URL)).to.be.true
                done()
                
        it 'инициализация с ошибкой', (done) ->

            stub= sandbox.stub(MongoDb, "connect").yields(err = {})
            spy = sandbox.spy(logStub, "fatal")

            db.init (err, db) ->

                expect(err).to.not.be.null
                expect(db).to.be.undefined
                expect(spy.calledOnce).to.be.true
                expect(stub.calledWithMatch(config.db.URL)).to.be.true
                done()

    describe 'shutDown', () ->
        
        it 'закрытие соединения с базой',  (done) ->

            spy = sandbox.spy(db.nativeDb, "close")

            db.shutDown (err) ->

                expect(err).to.be.null
                expect(spy.calledOnce).to.be.true
                done()
