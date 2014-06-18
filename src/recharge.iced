
{make_esc} = require 'iced-error'
minimist = require 'minimist'
path = require 'path'
fs = require 'fs'
log = require 'iced-logger'
{dict_merge,a_json_parse} = require('iced-utils').util
btcjs = require 'keybase-bitcoinjs-lib'
{Client} = require 'bitcoin'
{Base} = require './base'

#====================================================================================

SATOSHI_PER_BTC = 100 * 1000 * 1000

#====================================================================================

exports.Runner = class Runner 

  #-----------------------------------

  constructor : () ->
    super()

  #-----------------------------------

  get_opts : () ->
    dict_merge @get_opts_base(), {
      alias :
        c : 'config'
        t : 'to-address'
        o : 'num-outputs'  
    }

  #-----------------------------------

  # We're recharging the from address
  to_address : () -> @args['to-address'] or @config['from-address']
  num_outputs : () -> @icfg 'num-outputs'

  #-----------------------------------

  is_good_input_tx : (tx) ->
    amt = tx.amount * SATOSHI_PER_BTC
    diff = amt - @tx_rough_total
    if (diff > 0) and (tx.account is account())
      ret = -diff # We want the transaction with the most wiggle room, not the least...
    else
      ret = null

  #-----------------------------------

  tx_subtotal : () ->
    # The number of outputs, each trying to send a min amount (including TX fee)
    st = @num_outputs()*@min_amount()

  #-----------------------------------

  tx_rough_total : () ->
    # A rought sense for the transaction cost, which is likely an overestimate.
    @tx_subtotal() + Math.ceil(btcjs.networks.bitcoin.feePerKb * ((@num_outputs() + 2 )/150))

  #-----------------------------------

  check_args : (cb) ->
    err = null
    if not @to_address()? then err = new Error "no to address to work with (specify with -a)"
    else if not @account()? then err = new Error "need to specify an 'account' with -A"
    else if not @num_outputs()? then err = new Error "need to specify # of outputs with -o"
    cb err

  #-----------------------------------

  get_private_key : (cb) ->
    await @client.dumpPrivKey @input_tx.address, defer err, @priv_key
    cb err

  #-----------------------------------

  make_change_address : (cb) ->
    await @client.getNewAddress @account(), defer err, @change_address
    cb err

  #-----------------------------------

  make_transaction : (cb) ->
    err = null
    @data_to_address = (new btcjs.Address @to_address(), 0).toBase58Check()
    tx = new btcjs.Transaction
    tx.addInput @input_tx.txid, @input_tx.vout
    num = @num_outputs()
    for i in [0...num]
      tx.addOutput @data_to_address, @min_amount()
    skey = btcjs.ECKey.fromWIF @priv_key

    # Sign temporarily with a fictitious amount of change
    change_offset = tx.addOutput @change_address, 1
    tx.sign 0, skey

    fee = btcjs.networks.bitcoin.estimateFee(tx)
    @change = @input_tx.amount * SATOSHI_PER_BTC - num*@min_amount() - fee
    if change < 0
      err = new Error "Cannot transfer a negative amount of change"
    else
      tx.outs[change_offset].value = @change
      tx.sign 0, skey
      @out_tx = tx
    cb err

  #-----------------------------------

  submit_transaction : (cb) ->
    #await @client.sendRawTransaction @out_tx.toHex(), defer err, @out_tx_id
    console.log @out_tx.toHex()
    cb err

  #-----------------------------------

  write_output : (cb) ->
    console.log JSON.stringify {
      @out_tx_id,
      @data_to_address,
      @change,
      @change_address,
      input_tx_id : @input_tx.txid
    }
    cb null

  #-----------------------------------

  run : (argv, cb) ->
    esc = make_esc cb, "Runner::main"
    await @init esc defer()
    await @find_transaction esc defer()
    await @get_private_key esc defer()
    await @make_transaction esc defer()
    await @submit_transaction esc defer()
    await @write_output esc defer()
    cb null

  #-----------------------------------

#====================================================================================

exports.run = () ->
  r = new Runner
  await r.run process.argv[2...], defer err
  rc = 0
  if err?
    log.error err.message
    rc = err.rc or 2
  process.exit rc

#====================================================================================
