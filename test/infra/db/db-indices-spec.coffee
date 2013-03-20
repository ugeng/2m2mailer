process.env.NODE_ENV = 'test'
db = require '../../../src/infra/db'
dbIndices = require '../../../src/infra/db/db-indices'
collections = require '../../../src/infra/db/collections'
RES = require '../../../src/infra/RES'

#-----------------------------------------
# test helpers
#-----------------------------------------
# перенаправляем лог в заглушку, чтобы не засорять консоль
logStub = require('../../../src/infra/log').logStub

expect = require('chai').expect
ObjectID = require('mongodb').ObjectID
sinon = require('sinon')

describe 'db-indices', ->

    before (done) ->
        dbIndices.setLog(logStub)
        db.init (err, db) ->
            collections.init(db)
            done()

    after (done) ->
        db.shutDown ()->
            done()
        
    sandbox = {}

    beforeEach (done) ->
        sandbox = sinon.sandbox.create()
        done()

    afterEach (done) ->
        sandbox.restore()
        done()


    describe 'ensureIndices', () ->

        it 'нормальное создание индекса', (done) ->

            stub = sandbox.stub(collections.emails, "ensureIndex").yields(null, 'someIndex')

            dbIndices.ensureIndices (err, result) ->
                
                expect(err).to.be.null
                expect(result).to.equal RES.INDICES_ENSURED
                done()

        it 'создание индекса с ошибкой', (done) ->
            stub = sandbox.stub(collections.emails, "ensureIndex").yields(someErr = 'someError')
            spy = sandbox.spy(logStub, "fatal")
            
            dbIndices.ensureIndices (err, result) ->

                expect(err).to.equal(someErr)
                expect(result).to.be.undefined
                expect(spy.calledOnce).to.be.true
                done()                

            
