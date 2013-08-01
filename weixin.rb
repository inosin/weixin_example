require 'digest/sha1'
require 'nokogiri'
module Weixin
  class WeixinArgumentError < StandardError;end

  class Message

    def self.signature_valid?(token, params)
      Digest::SHA1.hexdigest(params.values_at(:timestamp, :nonce).unshift(token).sort.join) == params[:signature]
    rescue
      false
    end

    attr_accessor :to_user_name, :from_user_name, :create_time, :msg_type, :msg_id

    def initialize(body)
      @doc = Nokogiri::XML(body)
      @to_user_name = @doc.xpath('//ToUserName').inner_text
      @from_user_name = @doc.xpath('//FromUserName').inner_text
      @create_time = @doc.xpath('//CreateTime').inner_text
      @msg_type = @doc.xpath('//MsgType').inner_text
      @msg_id = @doc.xpath('//MsgId').inner_text
      send(:parse_msg, @msg_type)
    end

    def reply(type, options = {})
      raise WeixinArgumentError, "invalid reply message type: #{type}" unless %w(text music news).include?(type)
      send "reply_#{type}", options
    end

    private
    def parse_msg(type)
      raise WeixinArgumentError, "invalid message type: #{type}" unless %w(text image location link event).include?(type)
      send type
    end

    def build_reply(type)
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.xml {
          xml.ToUserName { xml.cdata @from_user_name }
          xml.FromUserName { xml.cdata @to_user_name }
          xml.CreateTime { xml.text Time.now.to_i }
          xml.MsgType { xml.cdata type }
          yield(xml)
        }
      end
      builder.to_xml
    end

    # <xml>
    # <ToUserName><![CDATA[toUser]]></ToUserName>
    # <FromUserName><![CDATA[fromUser]]></FromUserName> 
    # <CreateTime>1348831860</CreateTime>
    # <MsgType><![CDATA[text]]></MsgType>
    # <Content><![CDATA[this is a test]]></Content>
    # <MsgId>1234567890123456</MsgId>
    # </xml>
    def text
      class << self
        attr_accessor :content
      end
      @content = @doc.xpath('//Content').inner_text
    end

    # <xml>
    # <ToUserName><![CDATA[toUser]]></ToUserName>
    # <FromUserName><![CDATA[fromUser]]></FromUserName>
    # <CreateTime>1348831860</CreateTime>
    # <MsgType><![CDATA[image]]></MsgType>
    # <PicUrl><![CDATA[this is a url]]></PicUrl>
    # <MsgId>1234567890123456</MsgId>
    # </xml>
    def image
      class << self
        attr_accessor :pic_url
      end
      @pic_url = @doc.xpath('//PicUrl').inner_text
    end

    # <xml>
    # <ToUserName><![CDATA[toUser]]></ToUserName>
    # <FromUserName><![CDATA[fromUser]]></FromUserName>
    # <CreateTime>1351776360</CreateTime>
    # <MsgType><![CDATA[location]]></MsgType>
    # <Location_X>23.134521</Location_X>
    # <Location_Y>113.358803</Location_Y>
    # <Scale>20</Scale>
    # <Label><![CDATA[位置信息]]></Label>
    # <MsgId>1234567890123456</MsgId>
    # </xml> 
    def location
      class << self
        attr_accessor :location_x, :location_y, :scale, :label
      end
      @location_x = @doc.xpath('//Location_X').inner_text
      @location_y = @doc.xpath('//Location_Y').inner_text
      @scale = @doc.xpath('//Scale').inner_text
      @label = @doc.xpath('//Label').inner_text
    end

    # <xml>
    # <ToUserName><![CDATA[toUser]]></ToUserName>
    # <FromUserName><![CDATA[fromUser]]></FromUserName>
    # <CreateTime>1351776360</CreateTime>
    # <MsgType><![CDATA[link]]></MsgType>
    # <Title><![CDATA[公众平台官网链接]]></Title>
    # <Description><![CDATA[公众平台官网链接]]></Description>
    # <Url><![CDATA[url]]></Url>
    # <MsgId>1234567890123456</MsgId>
    # </xml>
    def link
      class << self
        attr_accessor :title, :description, :url
      end
      @title = @doc.xpath('//Title').inner_text
      @description = @doc.xpath('//Description').inner_text
      @url = @doc.xpath('//Url').inner_text
    end

    # <xml><ToUserName><![CDATA[toUser]]></ToUserName>
    # <FromUserName><![CDATA[FromUser]]></FromUserName>
    # <CreateTime>123456789</CreateTime>
    # <MsgType><![CDATA[event]]></MsgType>
    # <Event><![CDATA[EVENT]]></Event>
    # <EventKey><![CDATA[EVENTKEY]]></EventKey>
    # </xml>
    def event
      class << self
        attr_accessor :event, :eventKey
        EVENT_TYPES = %w(subscribe unsubscribe CLICK)
      end
      @event = @doc.xpath('//Event').inner_text
      @eventKey = @doc.xpath('//EventKey').inner_text
    end

    # <xml>
    # <ToUserName><![CDATA[toUser]]></ToUserName>
    # <FromUserName><![CDATA[fromUser]]></FromUserName>
    # <CreateTime>12345678</CreateTime>
    # <MsgType><![CDATA[text]]></MsgType>
    # <Content><![CDATA[content]]></Content>
    # </xml>
    def reply_text(options)
      build_reply('text') do |xml|
        xml.Content { xml.cdata options[:content] }
      end
    end

    # <xml>
    # <ToUserName><![CDATA[toUser]]></ToUserName>
    # <FromUserName><![CDATA[fromUser]]></FromUserName>
    # <CreateTime>12345678</CreateTime>
    # <MsgType><![CDATA[music]]></MsgType>
    # <Music>
    # <Title><![CDATA[TITLE]]></Title>
    # <Description><![CDATA[DESCRIPTION]]></Description>
    # <MusicUrl><![CDATA[MUSIC_Url]]></MusicUrl>
    # <HQMusicUrl><![CDATA[HQ_MUSIC_Url]]></HQMusicUrl>
    # </Music>
    # </xml>
    def reply_music(music)
      build_reply('music') do |xml|
        xml.Music {
          xml.Title { xml.cdata music[:title] }
          xml.Description { xml.cdata music[:description] }
          xml.MusicUrl { xml.cdata music[:music_url] }
          xml.HQMusicUrl { xml.cdata music[:hq_music_url] }
        }
      end
    end

    # <xml>
    #  <ToUserName><![CDATA[toUser]]></ToUserName>
    #  <FromUserName><![CDATA[fromUser]]></FromUserName>
    #  <CreateTime>12345678</CreateTime>
    #  <MsgType><![CDATA[news]]></MsgType>
    #  <ArticleCount>2</ArticleCount>
    #  <Articles>
    #  <item>
    #  <Title><![CDATA[title1]]></Title> 
    #  <Description><![CDATA[description1]]></Description>
    #  <PicUrl><![CDATA[picurl]]></PicUrl>
    #  <Url><![CDATA[url]]></Url>
    #  </item>
    #  <item>
    #  <Title><![CDATA[title]]></Title>
    #  <Description><![CDATA[description]]></Description>
    #  <PicUrl><![CDATA[picurl]]></PicUrl>
    #  <Url><![CDATA[url]]></Url>
    #  </item>
    #  </Articles>
    #  </xml>
    def reply_news(news)
      build_reply('news') do |xml|
        xml.ArticleCount news.count
        xml.Articles {
          news.each do |m|
            xml.item {
              xml.Title { xml.cdata m[:title] }
              xml.Description { xml.cdata m[:description] }
              xml.PicUrl { xml.cdata m[:pic_url] }
              xml.Url { xml.cdata m[:url] }
            }
          end
        }
      end
    end

  end

end