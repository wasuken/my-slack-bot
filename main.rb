# coding: utf-8
require 'parseconfig'
require 'slack-ruby-client'
require 'open-uri'

CONFIG=ParseConfig.new('config')
Slack.configure do |conf|
  conf.token = CONFIG["token"]
end
client = Slack::RealTime::Client.new

def search_connpass(keywords,num=10)
  return "" if keywords.join.gsub(" ","").size <= 0
  q=keywords.map{|k| "keyword=#{URI.encode(k)}"}.join("&")
  uri = URI.parse "https://connpass.com/api/v1/event/?#{q}"
  p uri
  response = Net::HTTP.start(uri.host, uri.port, :use_ssl => true) { |http|
    request = Net::HTTP::Get.new uri
    http.request request
  }
  json = JSON.parse response.body

  p json["events"].take(num).map{|i| i["title"]}
end

client.on :message do |data|
  case data.text
  when 'bot hi' then
    client.message channel: data.channel, text: "Hi <@#{data.user}>!"
  when /^bot/ then
    client.message channel: data.channel, text: "Sorry <@#{data.user}>, what?"
  when 'ひなこのーと' then
    client.message channel: data.channel, text: "おおきくすって、せーのっ"
  when /^connpass/ then
    titles = search_connpass(data.text.split(" ").drop(1),20)
    client.message channel: data.channel, text: titles.join("\n")
  end
end

client.on :close do |_data|
  puts "Client is about to disconnect"
end

client.on :closed do |_data|
  puts "Client has disconnected successfully!"
end

client.start!
