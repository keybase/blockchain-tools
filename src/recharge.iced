
{make_esc} = require 'iced-error'
minimist = require 'minimist'
path = require 'path'
fs = require 'fs'
request = require 'request'
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
    diff = amt - @tx_rough_total()
    if (diff > 0) and (tx.account is @account()) and (tx.confirmations >= @min_confirmations())
      ret = -diff # We want the transaction with the most wiggle room, not the least...
    else
      ret = null
    return ret

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
    if not @to_address()? then err = new Error "no to address to work with (specify with -t)"
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

  # Estimates fee per byte for a specific network opts.type needed to achieve
  # verification before opts.maxClearanceMins minutes For bitcoin, returns in
  # satoshis and uses the 21.co API with no fallback.
  marginal_fee_estimator: (opts, cb) ->
    esc = make_esc cb,'marginal_fee_estimator'
    if opts.type == 'bitcoin'
      apiUrl = 'https://bitcoinfees.21.co/api/v1/fees/list'
      await request apiUrl, esc defer resp, body
      if resp.statusCode == 200
        fees = JSON.parse(body)['fees']
        currentClearanceMins = 10000
        idx = 0
        while idx < fees.length and currentClearanceMins >= opts.maxClearanceMins
          fee = fees[idx]
          currentClearanceMins = fee['maxMinutes']
          currentFee = fee['maxFee']
          idx++
        cb null, currentFee
      else if resp.statusCode == 429
        cb new Error("API limit has been reached"), 0
    else if opts.type == 'litecoin'
      cb null, 100
    else
      cb new Error("Unknown cryptocurrency " + opts.type), 0

  # Estimates fee needed to send a transaction based on
  # the parameters in @marginal_fee_estimator, capped by
  # opts.feePerByteLimit and multiplied by opts.padding.
  # No default parameters set.
  fee_estimator : (opts, cb) ->
    esc = make_esc cb,'fee_estimator'
    await @marginal_fee_estimator opts, esc defer marginalFeeEstimate
    feePerByte = Math.min opts.feePerByteLimit, marginalFeeEstimate
    byteSize = opts.tx.toBuffer().length
    fee = feePerByte * byteSize * opts.padding
    cb err, fee

  make_transaction : (cb) ->
    err = null
    esc = make_esc cb,'make_transaction'
    tx = new btcjs.Transaction
    tx.addInput @input_tx.txid, @input_tx.vout
    num = @num_outputs()
    for i in [0...num]
      tx.addOutput @to_address(), @min_amount()
    skey = btcjs.ECKey.fromWIF @priv_key

    # Sign temporarily with a fictitious amount of change
    change_offset = tx.addOutput @change_address, 1
    tx.sign 0, skey

    # Can change these settings...
    btc_opts = {
        type: 'bitcoin',
        maxClearanceMinutes: 1800,
        tx: tx,
        feePerByteLimit: 1000,
        padding: 1
    }
    await @fee_estimator btc_opts, esc defer fee

    @change = @input_tx.amount * SATOSHI_PER_BTC - num*@min_amount() - fee
    if @change < 0
      err = new Error "Cannot transfer a negative amount of change"
    else
      tx.outs[change_offset].value = @change
      tx.sign 0, skey
      @out_tx = tx
    cb err

  #-----------------------------------

  submit_transaction : (cb) ->
    err = null
    await @client.sendRawTransaction @out_tx.toHex(), defer err, @out_tx_id
    console.error "Raw transaction: " + @out_tx.toHex()
    cb err

  #-----------------------------------

  write_output : (cb) ->
    console.log JSON.stringify {
      @out_tx_id,
      to_address : @to_address(),
      @change,
      @change_address,
      input_tx_id : @input_tx.txid
    }
    cb null

  #-----------------------------------

  run : (argv, cb) ->
    esc = make_esc cb, "Runner::main"
    await @init argv, esc defer()
    await @find_transaction esc defer()
    await @get_private_key esc defer()
    await @make_change_address esc defer()
    await @make_transaction esc defer()
    await @submit_transaction esc defer()
    await @write_output esc defer()
    cb null

  #-----------------------------------

#====================================================================================

exports.run = () -> run Runner
exports.Runner = Runner

#====================================================================================
