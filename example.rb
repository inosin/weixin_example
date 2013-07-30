# encoding: utf-8

require 'rubygems'
require 'bundler'
require 'digest/sha1'
Bundler.require

TOKEN = 'test_token'

get '/wx' do
  check_signature
end

private
def check_signature
  params[:echostr] if Digest::SHA1.hexdigest(params.values_at(:timestamp, :nonce).unshift(TOKEN).sort.join) == params[:signature]
rescue
  false
end