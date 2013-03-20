class Result
    constructor: (@message, @isError) ->
        if !@isError?
            @isError = false

Result::is = (result) ->
    if result?
        return @code == result.code
    else
        return false

Result::extend = (fields) ->
    newObject = new Result(@message, @isError)
    newObject.code = @code
    for own k, v of fields
        newObject[k] = v
    return newObject

#
# Файл содержащий объекты которые могут передавать функции в коллбеках в качестве результата выполнения
# Также данные объекты могут передаваться на клиента
#
RES = {

    INTERNAL_ERROR: new Result('Внутренняя ошибка', true)
    INVALID_ARGUMENTS: new Result('Неверные аргументы', true)
    INVALID_ADDRESS: new Result('Неверный адрес', true)

    INVALID_SEND_RESULT: new Result('Передан неверно сформированный результат отправки писем', true)
    
    EMAIL_SENT: new Result('Письмо отправлено')
    EMAIL_NOT_SENT: new Result('Не удалось отправить письмо', true)

    EMAILS_NOT_FOUND: new Result('Писем не найдено', true)

    INDICES_ENSURED: new Result('Индексы созданы')

    UPDATE_NOT_ALL_DOCUMENTS_INVOLVED: new Result('Модифицированы не все документы', true)
}

for own k, v of RES
    v.code = k

module.exports = RES
