
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
    # Need to confirm: how is ((@num_outputs() + 2 )/150)) estimating kb? empirical?
    @tx_subtotal() + Math.ceil(@marginal_fee_per_byte * 1000 * ((@num_outputs() + 2 )/150))

  #-----------------------------------

  check_args : (cb) ->
    err = null
    if not @to_address()? then err = new Error "no to address to work with (specify with -t)"
    else if not @account()? then err = new Error "need to specify an 'account' with -A"
    else if not @num_outputs()? then err = new Error "need to specify # of outputs with -o"
    else if not @fee_per_byte_limit()? then err = new Error "need to specify fee-per-byte-limit in config file"
    else if not @max_clearance_minutes()? then err = new Error "need to specify max-clearance-minutes in config file"
    else if not @padding()? then err = new Error "need to specify padding in config file"
    else if not @debug()? then err = new Error "need to specify debug with -d parameter or in config file"
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

    fee = @fee_estimator { tx: tx }

    if @debug()
      expected_fee = num*@min_amount() + fee
      console.log 'Number of inner transactions: ', num
      console.log "Expected total fee: #{expected_fee} satoshis, #{expected_fee * @usd_per_satoshi} USD"
      console.log "Fee per inner transaction: #{@min_amount()} satoshis, #{@min_amount() * @usd_per_satoshi} USD"
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
    if @debug()
      console.log("Running in debug mode")
    else
      console.log("Not running in debug mode")
    await @find_transaction esc defer()
    await @get_private_key esc defer()
    await @make_change_address esc defer()
    await @make_transaction esc defer()
    if !@debug()
      await @submit_transaction esc defer()
    await @write_output esc defer()
    cb null

  #-----------------------------------

#====================================================================================

exports.run = () -> run Runner
exports.Runner = Runner

#====================================================================================
