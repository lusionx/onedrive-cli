request = require 'request'
_       = require 'lodash'
program = require 'commander'
fs      = require 'fs'
wfall   = require 'water-fall'
log4js  = require 'log4js'

logger  = log4js.getLogger()

client_id = '0f207c76-5a22-4f74-9e47-ee2c038f3a70'
client_secret = '9e0U23VomDjwj4pS3Rg1MKq'
redirect_uri = 'http://localhost'
scope = 'offline_access files.readwrite.all'


getToken = (code, fin) ->
  return if not code
  par =
    uri: 'https://login.microsoftonline.com/common/oauth2/v2.0/token'
    method: 'POST'
    form:
      client_id: client_id
      redirect_uri: redirect_uri
      client_secret: client_secret
      code: code
      grant_type: 'authorization_code'
    json: yes
  request par, (err, resp, body) ->
    fin? err, body

dirve = (access_token, fin) ->
  par =
    uri: 'https://graph.microsoft.com/v1.0/me/drive/root/children'
    headers:
      Authorization: 'bearer ' + access_token
    method: 'GET'
    json: yes
  request par, (err, resp, body) ->
    console.log '%j', body
    fin? err


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
    open: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=#{client_id}&scope=#{encodeURIComponent scope}&response_type=code&redirect_uri=#{encodeURIComponent redirect_uri}"
  wf.push (hooks, callback) ->
    console.log "OPEN", hooks.open
    getInput (err, code) ->
      hooks.code = code
      callback()
  wf.push (hooks, callback) ->
    getToken hooks.code, (err, auth) ->
      hooks.auth = auth
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
      logger.debug body if body.err
      _.each body.value, (e) ->
        logger.info '%j', _.omit e, ['createdBy', 'lastModifiedBy', 'parentReference']
      callback()
  wf.exec (err) ->


defaultOptions =
  ROOT: 'https://graph.microsoft.com'
  user: '/v1.0/me'
  dirve: '/drive'
  authinfo: '.odAuthInfo'

main = () ->
  program.version '1.0.0'
    .option '-u --user [id]', 'prefix eg. /v1.0/users/{id}, default ' + defaultOptions.user
    .option '-d --drive [id]', 'select dirve eg. dirves/{id}, default ' + defaultOptions.dirve

  program.command 'auth'
    .description 'show auth uri && wait for {code} from stdin'
    .option '-a --authinfo <filename>', 'save auth-info'
    .action (options) ->
      cmdAuth _.extend {}, options, defaultOptions

  program.command 'show <res>'
    .description 'show list/drive'
    .option '-p --path [name]', 'item id/name'
    .action (name, options) ->
      par = _.extend {}, defaultOptions, _.pick options, ['path'].concat _.keys defaultOptions
      cmdShowList par if name is 'list'

  program.parse process.argv


module.exports = {main}
do main if process.argv[1] is __filename
