# encoding: utf-8

require 'rubygems'
require 'bundler'
Bundler.require
require './weixin'

TOKEN = 'test_token'

get '/wx' do
  params[:echostr] if Weixin::Message.signature_valid?(TOKEN, params)
end

post '/wx' do
  res = request.body.read
  weixin = Weixin::Message.new(res)
  case weixin.msg_type
  when 'text' then weixin.reply('text', :content => "你发送的内容为：#{weixin.content}")
  when 'image' then weixin.reply('text', :content => "你发送的图片为：#{weixin.pic_url}")
  when 'location' then weixin.reply('text', :content => "你发送的地址信息为：lx: #{weixin.location_x}, ly: #{weixin.location_y}, Scale: #{weixin.scale}, label: #{weixin.label}")
  when 'link'
    weixin.reply('news', [{:title => weixin.title, :description => weixin.description, :url => weixin.url, :pic_url => 'http://avatar.profile.csdn.net/3/5/5/2_inosin.jpg'}])
  when 'event'
    msg = case weixin.event
      when 'subscribe' then "#{weixin.eventKey} : 订阅成功"
      when 'unsubscribe' then "#{weixin.eventKey} : 取消订阅成功"
      when 'CLICK' then "#{weixin.eventKey} : 自定义事件"
      end
    weixin.reply('text', :content => msg)
  end
end