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
          response = @client.get_message_content(event.message["id"])
          case response
          when Net::HTTPSuccess then
            tf = Tempfile.open("content")
            file_path = tf.path
          else
            p "#{response.code} #{response.body}"
          end
          puts "●ここまで"
          url = "https://api.sonicAPI.com/analyze/chords?access_id=#{ENV['SONIC_API_KEY']}&input_file=#{file_path}"
          puts "url:#{url}"
          api = Api.new(url)
          puts "api.new"
          api.get
          puts "api.get"

        end
      end

    }

    head :ok
  end

end
