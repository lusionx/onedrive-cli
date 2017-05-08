request = require 'request'
async   = require 'async'
_       = require 'lodash'


getInput = (end, callback) ->
  input = ''
  process.stdin.resume()
  process.stdin.setEncoding('utf8')
  process.stdin.on 'data', (chunk) ->
    if chunk is end
      process.stdin.emit 'end'
      return callback null, _.trim(input)
    input += chunk
  process.stdin.on 'error', (err) ->
    console.error 'Could not read from stdin', err
  process.stdin.on 'end', () ->
    console.log 'stdin end', input


tryRequest = (par, cb) ->
  fn = (callback) ->
    request par, (err, resp, body) ->
      return callback err if err
      return callback new Error 'statusCode ' + resp.statusCode if resp.statusCode > 500
      callback err, {resp, body}
  async.retry 3, fn, (err, x) ->
    return cb err if err
    cb err, x.resp, x.body


module.exports = {getInput, request: tryRequest}
