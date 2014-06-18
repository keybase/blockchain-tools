
{make_esc} = require 'iced-error'
minimist = require 'minimist'
path = require 'path'
fs = require 'fs'
log = require 'iced-logger'
{athrow,dict_merge,a_json_parse} = require('iced-utils').util
btcjs = require 'keybase-bitcoinjs-lib'
{Client} = require 'bitcoin'
{run,SATOSHI_PER_BTC,Base} = require './base'
insert = require './insert'
request = require 'request'
pgpu = require 'pgp-utils'

#====================================================================================

exports.Runner = class Runner extends insert.Runner

  #-----------------------------------

  check_args : (cb) ->
    err = null
    if not (@url = @cfg("root-url"))? then err = new Error "no URL given"
    else if not (@status_file = @pcfg("status-file"))? then err = new Error "no status file given"
    else
      await super defer err
    cb err

  #-----------------------------------

  make_root_req : (cb) ->
    await request { @url, json : true }, defer err, res, data
    err = if err? then err
    else if res.statusCode isnt 200 then new Error("non-200-error: #{res.statusCode}")
    else if not (status = data?.status?.name)? then new Error "Can't get json.status.name"
    else if status isnt 'OK' then new Error "Got non-OK status: #{status}"
    else if not (sig = data.sig)? then new Error 'No signature found'
    else if not (@seqno = data.seqno)? then new Error "No seqno found"
    else 
      [err,m] = pgpu.armor.decode sig
      if not err? and ( not(@sig_body = m.body)? or @sig_body.length is 0)
        new Error "no signature body found after parsing"
      else
        @post_data = @hash = btcjs.crypto.hash160 @sig_body
        null
    cb err

  #-----------------------------------

  check_repeat : (cb) ->
    await @read_and_parse_json @status_file, defer err, json
    if err?.code is 'ENOENT' then err = null
    else if err? then # noop
    else if not(json.seqno)? then err = new Error "no seqno field in status file"
    else if typeof(json.seqno) isnt "number" then err = new Error "bad seqno field in status file"
    else if parseInt(json.seqno,10) >= @seqno then err = new Error "no need for update @#{@seqno}"
    cb err

  #-----------------------------------

  write_output : (cb) ->
    obj = JSON.stringify { @seqno, @out_tx_id, @data_to_address, hash : @hash.toString('hex') }
    console.error "Raw transaction: #{@out_tx.toHex()}"
    console.log obj
    await fs.writeFile @status_file, obj, defer err
    cb err

  #-----------------------------------

  make_post_data : (cb) -> 
    esc = make_esc cb, "Runner::make_post_data"
    await @make_root_req esc defer()
    await @check_repeat esc defer()
    cb null

  #-----------------------------------

#====================================================================================

exports.run = () -> run Runner 

#====================================================================================
