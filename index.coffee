request = require 'request'
async   = require 'async'
Path    = require 'path'
_       = require 'lodash'
program = require 'commander'
fs      = require 'fs'
wfall   = require 'water-fall'
mime    = require 'mime-types'
log4js  = require 'log4js'

helper  = require './helper'
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


# read token file
readToken = (options, callback) ->
  wf = wfall.create()
  wf.push (hooks, callback) ->
    fs.readFile options.authinfo, (err, str) ->
      return callback err if err
      hooks.auth = JSON.parse str
      logger.debug 'read_token', hooks.auth
      callback()
  refresh = (hooks) ->
    t = new Date hooks.auth.createdAt
    new Date() - t > 3600 * 1000
  wf.pushIf refresh, (hooks, callback) ->
    par =
      uri: 'https://login.microsoftonline.com/common/oauth2/v2.0/token'
      method: 'POST'
      form:
        client_id: hooks.auth.client_id
        client_secret: hooks.auth.client_secret
        grant_type: 'refresh_token'
        redirect_uri: options.redirect_uri
        refresh_token: hooks.auth.refresh_token
      json: yes
    request par, (err, resp, body) ->
      logger.debug 'refresh_token', body
      hooks.reauth = body
      d = _.extend {}, hooks.auth, {createdAt: new Date}, _.pick body, ['access_token', 'refresh_token']
      fs.writeFile options.authinfo, JSON.stringify(d), callback
  wf.exec (err, hooks) ->
    callback null, access_token: (hooks.reauth or hooks.auth).access_token


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
    helper.getInput '\n', (err, code) ->
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
        logger.info '%j', _.pick e, ['id', 'name']
      callback()
  wf.exec (err) ->


cmdShowDrive = (options) ->
  wf = wfall.create()
  wf.push (hooks, callback) ->
    readToken options, (err, auth) ->
      hooks.auth = auth
      callback()
  wf.push (hooks, callback) ->
    par =
      uri: [options.ROOT, options.user, '/drives'].join ''
      headers:
        Authorization: 'bearer ' + hooks.auth.access_token
      method: 'GET'
      json: yes
    logger.trace '%j', par
    request par, (err, resp, body) ->
      logger.error err if err
      logger.debug body if body.error
      _.each body.value, (e) ->
        logger.info '%j', e
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
    logger.trace '%j', par
    request par, (err, resp, body) ->
      logger.debug 'createUploadSession', body
      hooks.session = body
      callback()
  wf.push (hooks, callback) ->
    fs.readFile options.localpath, {encoding: null}, (err, data) ->
      logger.error err if err
      logger.info 'FILE',  options.localpath, 'LENGTH', data.length
      hooks.buffs = data
      callback()
  wf.push (hooks, callback) ->
    iter = (frag, fin) ->
      par =
        uri: hooks.session.uploadUrl
        headers:
          'Content-Range': "bytes #{frag.rangeF}-#{frag.rangeT}/#{hooks.buffs.length}"
          'Content-Length': frag.size
        method: 'PUT'
        body: hooks.buffs.slice frag.rangeF, frag.rangeF + frag.size
      logger.trace '%j', _.omit par, 'body'
      helper.request par, (err, resp, body) ->
        logger.error err if err
        logger.debug 'put fragment', resp.statusCode, resp.headers if resp
        if err or body?.error
          logger.warn body
        else
          logger.debug body
        fin null, JSON.parse body
    size = +options.size * Math.pow(2, 20)
    list = _.range hooks.buffs.length / size
    list = _.map list, (i) ->
      rangeF: f = i * size
      size: s = Math.min size, hooks.buffs.length - f
      rangeT: f + s - 1
    async.mapLimit list, 1, iter, (err, arr) ->
      hooks.item = _.find arr, (e) -> e and e.id and e.name
      callback()
  wf.push (hooks, callback) ->
    par =
      uri: hooks.session.uploadUrl
      headers: {}
      method: 'DELETE'
    logger.trace '%j', par
    request par, (err, resp) ->
      logger.error err if err
      logger.debug 'cancel session', resp.statusCode, resp.headers if resp
      callback null
  wf.exec (err, hooks) ->
    logger.info 'put success', hooks.item


defaultOptions =
  ROOT: 'https://graph.microsoft.com'
  logger: 'INFO'
  user: '/v1.0/me'
  dirve: '/drive'
  authinfo: '.odAuthInfo'
  scope: 'offline_access files.readwrite.all'
  redirect_uri: 'http://localhost'


main = () ->
  program.version '1.0.0'
    .option '-u --user [id]', 'prefix eg. /v1.0/users/{id}, default ' + defaultOptions.user
    .option '-d --drive [id]', 'select dirve eg. dirves/{id}, default ' + defaultOptions.dirve
    .option '--logger [level]', 'set logger level TRACE,DEBUG,{INFO},WARN,ERROR'

  pickParent = (options) -> _.pick options.parent, ['logger']

  program.command 'auth'
    .description 'show auth uri && wait for {code} from stdin'
    .option '--client_id <value>'
    .option '--client_secret <value>'
    .option '-a --authinfo <filename>', 'save auth-info'
    .action (options) ->
      par = _.extend {}, defaultOptions, pickParent(options), _.pick options, ['client_id', 'client_secret'].concat _.keys defaultOptions
      logger.setLevel par.logger
      cmdAuth par

  program.command 'show <res>'
    .description 'show list/drive'
    .option '-p --path [name]', 'item id/name'
    .action (name, options) ->
      par = _.extend {}, defaultOptions, pickParent(options), _.pick options, ['path'].concat _.keys defaultOptions
      logger.setLevel par.logger
      cmdShowList par if name is 'list'
      cmdShowDrive par if name is 'drive'

  program.command 'put <localpath>'
    .description 'upload file'
    .option '-p --path [name]', 'item id/name'
    .option '--size [number]', 'split file by ?MB before put'
    .action (name, options) ->
      par = _.extend {}, defaultOptions, pickParent(options), _.pick options, ['path', 'size'].concat _.keys defaultOptions
      logger.setLevel par.logger
      par.localpath = name
      par.path += Path.basename par.localpath if _.endsWith par.path, '/'
      fn = if par.size then cmdPutSession else cmdPut
      fn par

  program.parse process.argv


module.exports = {main}
do main if process.argv[1] is __filename
