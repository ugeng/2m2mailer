exports.emails = { }

exports.init = (db) ->
    exports.emails = db.collection('emails')
    