request = require 'request'
_       = require 'lodash'
program = require 'commander'
fs      = require 'fs'
wfall   = require 'water-fall'

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

getConfig = (callback) ->
  fs.readFile '.odconfig', (err, str) ->
    return callback err if err
    callback err, JSON.parse str


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
    return callback() if not v = options?.output
    fs.writeFile v, JSON.stringify(hooks.auth), (err) ->
      console.log 'save to', v
  wf.exec (err) ->
    console.error err if err


main = () ->
  program.version '1.0.0'
    .option '-u --user [id]', 'prefix eg. /v1.0/users/{id}, default /v1.0/me'
    .option '-d --drive [id]', 'select dirve eg. dirves/{id}, default /dirve'

  program.command 'auth'
    .description 'show auth uri && wait for {code} from stdin'
    .option '-o --output <filename>', 'save auth-info'
    .action (options) ->
      cmdAuth options

  program.command 'config <cmd>'
    .description 'get/set config'
    .alias 'c'
    .option '--all', 'get all'
    .action (cmd, options) ->
      console.log 'act1 %s with %j', cmd, options.all

  program.command 'show [name]'
    .description 'show :path items'
    .action (name, options) ->
      console.log 'act2 %s with %j', name, options

  program.parse process.argv


module.exports = {main}
do main if process.argv[1] is __filename
