
{make_esc} = require 'iced-error'
minimist = require 'minimist'
path = require 'path'
fs = require 'fs'
log = require 'iced-logger'
{dict_merge,a_json_parse} = require('iced-utils').util
btcjs = require 'keybase-bitcoinjs-lib'
{Client} = require 'bitcoin'
{run,SATOSHI_PER_BTC,Base} = require './base'

#====================================================================================

exports.Runner = class Runner extends Base

  #-----------------------------------

  constructor : () ->
    super()

  #-----------------------------------

  get_opts : () ->
    # Plus args._[0] is the data to put into the block chain, which has to be
    # 20 bytes long, encoded as a 40-character hex string.
    dict_merge @get_opts_base(), {
      alias :
        f : 'from-address'
    }

  #-----------------------------------

  from_address : () -> @cfg('from-address')

  #-----------------------------------

  is_good_input_tx : (tx) ->
    amt = tx.amount * SATOSHI_PER_BTC
    if (tx.address is @from_address()) and 
         (amt >= @min_amount()) and (amt <= @max_amount()) and
         (tx.confirmations >= @min_confirmations()) and
         (not(a = @account())? or (tx.account is a))
      ret = amt - @min_amount()
    else
      ret = null

  #-----------------------------------

  check_args : (cb) ->
    err = null
    if not @from_address()? then err = new Error "no from address to work with"
    cb err

  #-----------------------------------

  get_private_key : (cb) ->
    await @client.dumpPrivKey @from_address(), defer err, @priv_key
    cb err

  #-----------------------------------

  make_post_data : (cb) -> 
    raw = @args._[0]
    err = null
    if not raw? then err = new Error "not post data given"
    else if not raw.match /^[0-9a-fA-F]{40}$/ then err = new Error "post data must be a 40-btye hex hash"
    else @post_data = new Buffer(raw, 'hex')
    cb err

  #-----------------------------------

  make_transaction : (cb) ->
    @data_to_address = (new btcjs.Address @post_data, 0).toBase58Check()
    tx = new btcjs.Transaction
    tx.addInput @input_tx.txid, @input_tx.vout
    tx.addOutput @data_to_address, @amount()
    skey = btcjs.ECKey.fromWIF @priv_key
    tx.sign 0, skey
    @out_tx = tx
    cb null

  #-----------------------------------

  submit_transaction : (cb) ->
    await @client.sendRawTransaction @out_tx.toHex(), defer err, @out_tx_id
    cb err

  #-----------------------------------

  write_output : (cb) ->
    console.log JSON.stringify {
      @out_tx_id,
      @data_to_address
    }
    cb null

  #-----------------------------------

  run : (argv, cb) ->
    esc = make_esc cb, "Runner::main"
    await @init argv, esc defer()
    await @make_post_data esc defer()
    await @make_bitcoin_client esc defer()
    await @find_transaction esc defer()
    await @get_private_key esc defer()
    await @make_transaction esc defer()
    await @submit_transaction esc defer()
    await @write_output esc defer()
    cb null

#====================================================================================

exports.run = () -> run Runner 

#====================================================================================
