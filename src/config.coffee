# ------------------------------------
# Конфигурация программы
# ------------------------------------
exports.currentEnv = currentEnv = process.env.NODE_ENV || 'development'

exports.appName = "2m2"

exports.env =
    production: false
    staging: false
    test: false
    development: false

exports.env[currentEnv] = true

exports.log =
    path: __dirname + "/log/app_#{currentEnv}.log"

exports.server =
    port: 8080
    #In staging and production, listen loopback. nginx listens on the network.
    ip: '127.0.0.1'

if currentEnv not in ['production', 'staging']
    exports.enableTests = true
    #Listen on all IPs in dev/test (for testing from other machines)
    exports.server.ip = '0.0.0.0'
# ------------------------------------
# Конфигурация mongo
# ------------------------------------
module.exports.db =
    URL: "mongodb://localhost:27017/#{exports.appName.toLowerCase()}_#{currentEnv}"

module.exports.dbSessionStore =
    db: "#{exports.appName.toLowerCase()}_#{currentEnv}_sessions"
    host: "localhost"
    port: 27017
# ------------------------------------
# Конфигурация отправки почты
# ------------------------------------
module.exports.mailTransportType = "SMTP"

# ------------------------------------
#корневой каталог проекта, который подготавливает массив attachments для мэйлера (на данный момент это основной проект 2m2)
# мэйлер использует этот параметр для построения (конкатенации) пути с файлам вложений при заполнении messageData для node-mailer 
module.exports.attachmentsBaseDirectory = "../../2m2/"
# ------------------------------------
# настройки почтового транспорта
module.exports.mailTransportConfig = {
    service: "Gmail"
    #service: "smtp.gmail.com"
    #secureConnection: true
    #port: 465
    auth:
        user: "evgeniy.dolgy@gmail.com"
        pass: "salvadoor4g"
    from: "Сайт 2m2.ru <evgeniy.dolgy@gmail.com>"
    replyTo: "no-reply@2m2.ru" 
}

module.exports.checker = {
    clearOldCronJobPattern: '00 00 02 * * *' #runs every day in 02-00 am 
    
    handlePendingsCronJobPattern: '00 * * * * *' #runs every minute
    
    handleFailedCronJobPattern: '* */10 * * * *' #runs every 10 minutes
}