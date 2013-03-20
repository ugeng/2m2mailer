emailer = require("nodemailer")
fs      = require("fs")
_       = require("underscore")

config = require "../config"
RES = require "../infra/RES"

class Mailer

    constructor: (@mailTransportType, @transportConfig)->
        @transport = @getTransport()
        
    getTransport: ()->
        emailer.createTransport @mailTransportType, @transportConfig

        ###
    getHtml: (templateName, data)->
        templatePath = "./__src/app/views/emails/#{templateName}.html"
        templateContent = fs.readFileSync(templatePath, encoding="utf8")
        _.template templateContent, data, {interpolate: /\{\{(.+?)\}\}/g}
    
    getAttachments: (html)->
        attachments = []
        for attachment in @attachments
            attachments.push(attachment) if html.search("cid:#{attachment.cid}") > -1
        attachments
###

    setupAttachments: (attachments)->
        @messageData.attachments = [] if @messageData.attachments? == false 
        
        for attachment in attachments
            attachmentToSend = _.clone(attachment)
            #build a path to each non-binary attachment what used 'cid=' and path for mapping
            attachmentToSend.filePath = config.attachmentsBaseDirectory + attachment.filePath if attachment.cid? and attachment.filePath?
            @messageData.attachments.push(attachmentToSend)


    send: (email, callback)->
        if email? == false
            return callback RES.INVALID_ARGUMENTS
        if email.to? == false            
            return callback RES.INVALID_ADDRESS

        @messageData =
            to: email.to
            generateTextFromHTML: true

        @messageData.cc = email.cc if email.cc?
        @messageData.bcc = email.bcc if email.bcc?
        @messageData.subject = email.subject if email.subject?
        @messageData.html = email.body if email.body?

        @setupAttachments(email.attachments) if email.attachments?
            
        if @transport?
            @transport.sendMail @messageData, callback
            
module.exports.Mailer = Mailer
