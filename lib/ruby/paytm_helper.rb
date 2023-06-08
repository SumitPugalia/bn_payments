# import checksum generation utility
# require './PaytmChecksum.rb'
require 'json'
require_relative 'PaytmChecksum'

puts call(ARGV)

BEGIN {

  def call(args)
    function_name = args[0]
    send(function_name, args)
  end

  def create_checksum(args)
    # initialize JSON String
    # body = "{/*YOUR_COMPLETE_REQUEST_BODY_HERE*/}"
    merchant_key = args[1]
    body = JSON.parse(args[2])

    # Generate checksum by parameters we have
    # Find your Merchant Key in your Paytm Dashboard at https://dashboard.paytm.com/next/apikeys

    paytmChecksum = PaytmChecksum.new.generateSignature(body, merchant_key)
    return paytmChecksum
  end

  def validate_checksum(args)
    merchant_key = args[1]
    body = args[2]
    paytmChecksum = args[3]

    # Verify checksum
    # Find your Merchant Key in your Paytm Dashboard at https://dashboard.paytm.com/next/apikeys

    isVerifySignature = PaytmChecksum.new.verifySignature(body, merchant_key, paytmChecksum)
    return isVerifySignature
  end
  
}
