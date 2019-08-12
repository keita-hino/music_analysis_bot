# -*- coding: utf-8 -*-
class LinebotController < ApplicationController
  require 'line/bot'  # gem 'line-bot-api'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["MUSIC_ANALISIS_LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["MUSIC_ANALISIS_LINE_CHANNEL_TOKEN"]
    }
  end

  def callback
    body = request.body.read
    file_path = ""

    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end

    events = client.parse_events_from(body)
    # ただのテキストが送られたとき
    events.each { |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          case event.message['text']
          when '$creater','製作者'
            message = c.get_creater
            client.reply_message(event['replyToken'], message)
          else
            message = {
              type: "text",
              text: event.message["text"]
            }
            client.reply_message(event['replyToken'], message)
          end
        when Line::Bot::Event::MessageType::Audio
          
          message = {
            type: 'text',
            text: 'コード解析中...'
          }

          client.push_message(event["source"]["userId"], message)

          response = @client.get_message_content(event.message["id"])
          dir = "#{Rails.root}/tmp/"

          case response
          when Net::HTTPSuccess then
            tf = Tempfile.open("content")
            tf.write(response.body.force_encoding("ISO-8859-1").encode("UTF-8"))
            file_path = tf.path
            
            moved_path = "tmp/#{Time.now}.mp3"
            File.rename(file_path,moved_path)
          else
            p "#{response.code} #{response.body}"
          end
          
          debugger
          # file_path = "http://www.sonicAPI.com/music/brown_eyes_by_ueberschall.mp3"
          url = "https://api.sonicAPI.com/analyze/chords?access_id=#{ENV['SONIC_API_KEY']}&input_file=#{moved_path}&format=json"

          api = Api.new(url)
          json = api.get
          tmp = "コード解析したよ🎵\n"
          chords = tmp + json["chords_result"]["chords"].map{|v| v["chord"]}.join(",")

          message = {
            type: 'text',
            text: chords
          }
          
          client.reply_message(event['replyToken'], message)
          
        end
      end

    }

    head :ok
  end

end
