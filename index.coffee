request = require 'request'
async   = require 'async'
_       = require 'lodash'
program = require 'commander'
fs      = require 'fs'
wfall   = require 'water-fall'
mime    = require 'mime-types'
log4js  = require 'log4js'

logger  = log4js.getLogger()

getToken = (par, fin) ->
  par =
    uri: 'https://login.microsoftonline.com/common/oauth2/v2.0/token'
    method: 'POST'
    form:
      client_id: par.client_id
      redirect_uri: par.redirect_uri
      client_secret: par.client_secret
      code: par.code
      grant_type: 'authorization_code'
    json: yes
  request par, (err, resp, body) ->
    fin? err, body


getInput = (callback) ->
  input = ''
  process.stdin.resume()
  process.stdin.setEncoding('utf8')
  process.stdin.on 'data', (chunk) ->
    if chunk is '\n'
      process.stdin.emit 'end'
      return callback null, _.trim(input)
    input += chunk
  process.stdin.on 'error', (err) ->
    console.error 'Could not read from stdin', err
  process.stdin.on 'end', () ->
    console.log 'stdin end', input


# read token file
readToken = (options, callback) ->
  fs.readFile options.authinfo, (err, str) ->
    return callback err if err
    callback err, JSON.parse str


cmdAuth = (options) ->
  wf = wfall.create
    open: [
      "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?"
      "client_id=#{options.client_id}&"
      "scope=#{encodeURIComponent options.scope}&"
      "response_type=code&"
      "redirect_uri=#{encodeURIComponent options.redirect_uri}"
    ].join ''
  wf.push (hooks, callback) ->
    console.log "OPEN", hooks.open
    getInput (err, code) ->
      hooks.code = code
      callback()
  wf.push (hooks, callback) ->
    par = _.extend {}, {code: hooks.code}, _.pick options, ['client_id', 'client_secret', 'redirect_uri']
    getToken par, (err, auth) ->
      hooks.auth = _.extend auth,
        createdAt: new Date()
        client_id: options.client_id
        client_secret: options.client_secret
      callback()
  wf.push (hooks, callback) ->
    console.log hooks.auth
    return callback() if not v = options?.authinfo
    fs.writeFile v, JSON.stringify(hooks.auth), (err) ->
      console.log 'save to', v
  wf.exec (err) ->
    console.error err if err


cmdShowList = (options) ->
  wf = wfall.create()
  wf.push (hooks, callback) ->
    readToken options, (err, auth) ->
      hooks.auth = auth
      callback()
  wf.push (hooks, callback) ->
    p = if v = options.path then ':/' + v + ':' else ''
    par =
      uri: [options.ROOT, options.user, options.dirve, '/root', encodeURIComponent(p), '/children'].join ''
      headers:
        Authorization: 'bearer ' + hooks.auth.access_token
      method: 'GET'
      json: yes
    logger.trace '%j', par
    request par, (err, resp, body) ->
      logger.error err if err
      logger.debug body if body.error
      _.each body.value, (e) ->
        logger.info '%j', _.omit e, ['createdBy', 'lastModifiedBy', 'parentReference']
      callback()
  wf.exec (err) ->


cmdPut = (options) ->
  wf = wfall.create
    stream: fs.createReadStream options.localpath
  wf.push (hooks, callback) ->
    readToken options, (err, auth) ->
      hooks.auth = auth
      callback()
  wf.push (hooks, callback) ->
    p = if v = options.path then ':/' + v + ':' else ''
    par =
      uri: [options.ROOT, options.user, options.dirve, '/root', encodeURIComponent(p), '/content'].join ''
      headers:
        Authorization: 'bearer ' + hooks.auth.access_token
        'Content-Type': mime.lookup options.localpath
      method: 'PUT'
      body: hooks.stream
    logger.trace '%j', _.omit par, 'body'
    request par, (err, resp, body) ->
      logger.error err if err
      logger.debug body if body.error
      logger.debug body
  wf.exec (err) ->


cmdPutSession = (options) ->
  wf = wfall.create do ->
    d =
      itempath: if v = options.path then ':/' + v + ':' else ''
    d
  wf.push (hooks, callback) ->
    readToken options, (err, auth) ->
      hooks.auth = auth
      callback()
  wf.push (hooks, callback) -> # createUploadSession
    p = hooks.itempath
    par =
      uri: [options.ROOT, options.user, options.dirve, '/root', encodeURIComponent(p), '/createUploadSession'].join ''
      headers:
        Authorization: 'bearer ' + hooks.auth.access_token
        'Content-Type': mime.lookup options.localpath
      method: 'POST'
      json: yes
    request par, (err, resp, body) ->
      logger.debug body
      hooks.session = body
      callback()
  wf.push (hooks, callback) ->
    fs.readFile options.localpath, {encoding: null}, (err, data) ->
      logger.error err if err
      logger.debug 'file length', data.length
      hooks.buffs = _.chunk data, 5 * 1024 * 1024
      callback()
  wf.push (hooks, callback) ->
    last = null
    iter = (buf, fin) ->
      par =
        uri: hooks.session.uploadUrl
        headers:
          'Content-Range': hooks.session.nextExpectedRanges[0] + (buf.length - 1) + '/128'
          'Content-Length': buf.length
        method: 'PUT'
        body: Buffer.from buf
      logger.trace '%j', _.omit par, 'body'
      request par, (err, resp, body) ->
        logger.error err if err
        logger.debug body if body.error
        logger.debug body
    async.eachLimit hooks.buffs, 1, iter

  wf.exec (err) ->


defaultOptions =
  ROOT: 'https://graph.microsoft.com'
  user: '/v1.0/me'
  dirve: '/drive'
  authinfo: '.odAuthInfo'
  scope: 'offline_access files.readwrite.all'
  redirect_uri: 'http://localhost'


main = () ->
  program.version '1.0.0'
    .option '-u --user [id]', 'prefix eg. /v1.0/users/{id}, default ' + defaultOptions.user
    .option '-d --drive [id]', 'select dirve eg. dirves/{id}, default ' + defaultOptions.dirve

  program.command 'auth'
    .description 'show auth uri && wait for {code} from stdin'
    .option '--client_id <value>'
    .option '--client_secret <value>'
    .option '-a --authinfo <filename>', 'save auth-info'
    .action (options) ->
      par = _.extend {}, defaultOptions, _.pick options, ['client_id', 'client_secret'].concat _.keys defaultOptions
      cmdAuth par

  program.command 'show <res>'
    .description 'show list/drive'
    .option '-p --path [name]', 'item id/name'
    .action (name, options) ->
      par = _.extend {}, defaultOptions, _.pick options, ['path'].concat _.keys defaultOptions
      cmdShowList par if name is 'list'

  program.command 'put <localpath>'
    .description 'show list/drive'
    .option '-p --path [name]', 'item id/name'
    .option '--session', 'item id/name'
    .action (name, options) ->
      par = _.extend {}, defaultOptions, _.pick options, ['path', 'session'].concat _.keys defaultOptions
      par.localpath = name
      fn = if par.session then cmdPutSession else cmdPut
      fn par

  program.parse process.argv


module.exports = {main}
do main if process.argv[1] is __filename
