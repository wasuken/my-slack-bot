# coding: utf-8
require 'parseconfig'
require 'slack-ruby-client'
require 'open-uri'
require 'sqlite3'
require 'sequel'
require 'fileutils'

CONFIG=ParseConfig.new('config')
Slack.configure do |conf|
  conf.token = CONFIG["token"]
end
client = Slack::RealTime::Client.new

DB = Sequel.sqlite(CONFIG["db_path"])

def search_connpass(keywords,num=10)
  return "" if keywords.join.gsub(" ","").size <= 0
  q=keywords.map{|k| "keyword=#{URI.encode(k)}"}.join("&")
  uri = URI.parse "https://connpass.com/api/v1/event/?#{q}"
  response = Net::HTTP.start(uri.host, uri.port, :use_ssl => true) { |http|
    request = Net::HTTP::Get.new uri
    http.request request
  }
  json = JSON.parse response.body

  p json["events"].take(num).map{|i| i["title"]}
end
def memo_order(order,vals)
  case order
  when /^add/ then
    DB[:memo].insert(book_name: vals.first, memo: vals.drop(1).join)
    return memo_order("show", [])
  when /^rm/ then
    DB[:memo].filter(id: vals).delete
    return memo_order("show", [])
  when /^upd/ then
    DB[:memo].filter(id: vals.first).update(book_name: vals.drop(1).first,
                                            memo: vals.drop(2).first)
    return memo_order("show", [])
  when /^show/ then
    recs = DB[:memo].take(10).map{|i| "id:" + (i[:id].to_s||"") +
                             ",book_name:"+(i[:book_name]||"") +
                             ",memo:" + (i[:memo]||"")}
    p recs
    return recs.join("\n")
  when /^recreate/ then
    DB.run("drop table memo;create table memo(id integer primary key,book_name text,memo text)")
    return "recreate!"
  end
end

client.on :message do |data|
  case data.text
  when 'bot hi' then
    client.message channel: data.channel, text: "こんにちわ <@#{data.user}>!"
  when /^bot/ then
    client.message channel: data.channel, text: "はい <@#{data.user}>, どうしましたか?"
  when 'ひなこのーと' then
    client.message channel: data.channel, text: "<@#{data.user}>, おおきくすって、せーのっ"
  when 'ガヴリールドロップアウト'
    client.message channel: data.channel, text: "<@#{data.user}>, ガヴリールドロップアウト"
  when /^connpass/ then
    titles = search_connpass(data.text.split(" ").drop(1),20)
    client.message channel: data.channel, text: titles.join("\n")
  when /^readmemo/ then
    keywords=data.text.split(" ").drop(1)
    ord_result = memo_order(keywords.first, keywords.drop(1))
    client.message channel: data.channel, text: ord_result
  end
end

client.on :close do |_data|
  puts "Client is about to disconnect"
end

client.on :closed do |_data|
  puts "Client has disconnected successfully!"
end

client.start!
