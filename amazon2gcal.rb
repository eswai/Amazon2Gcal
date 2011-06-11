# -*- coding: UTF-8 -*-

require 'rubygems'
require 'gcalapi'
require './amazon_ws'
require 'yaml'
require 'pp'

# load config file
if ARGV.size > 0 then
  config = YAML::load_file(ARGV[0])
else
  config = YAML::load_file("amazon2gcal.yaml")
end

srv = GoogleCalendar::Service.new(config["account"], config["password"])
cal = GoogleCalendar::Calendar::new(srv, config["feed"])

as = AmazonService.new(config["aws-key"].strip, config["secret-key"].strip, config["target"])
items = as.future_items

# 本日以降の予定を消去
events = cal.events(:"max-results" => 200, :"start-min" => Date.today)
puts "#{events.size} items to be deleted."
events.each{|e|
  e.destroy!
}

# 予定の追加
print "#{items.size} items to be added.\n"
items.each do |i|
  puts i.title + " / " + (i.author || "-")
  event = cal.create_event
  event.allday = true
  event.title = i.title + " / " + (i.author || "-")
  event.desc = i.uri
  event.st = i.date
  event.en = i.date
  event.save!
end
