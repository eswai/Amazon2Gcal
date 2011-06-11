# -*- coding: UTF-8 -*-

require 'rubygems'
require 'amazon/ecs'
require 'date'
require 'uri'
require 'pp'
require 'kconv'

module Amazon
  class Ecs
    private
      def self.url_encode(str)
        str.gsub(/([^ a-zA-Z0-9_.-]+)/){'%' + $1.unpack('H2' * $1.bytesize).join('%').upcase}.gsub(' ', '%20')
      end
  end
end


class Item
  attr_accessor :author
  attr_accessor :date
  attr_accessor :title
  attr_accessor :asin

  def initialize(amz_result, keyalias)
    ia = amz_result.get_hash('itemattributes')
    @title = ia[keyalias[:title]].force_encoding('UTF-8')
    @author = (ia[keyalias[:author]] || '').force_encoding('UTF-8')
    @date = parseDate(ia[keyalias[:date]])
    @asin = amz_result.get('asin')
  end
  
  def gettext(var)
    if var == nil then
      ""
    else
      var.text
    end
  end
  
  def parseDate(str)
    if /\d+-\d+-\d+/ =~ str then
      d = Date.parse(str)
      Time.mktime(d.year, d.mon, d.day)
    elsif /\d+-\d+/ =~ str then
      d = Date.parse(str + "-01")
      Time.mktime(d.year, d.mon, d.day)
    else
      nil
    end
  end
  
  def to_s
    @title + " / " + (@author || "") + " / " + self.uri
  end
  
  def uri
    "http://www.amazon.co.jp/gp/product/" + @asin
  end
  
  def eql?(other)
    @asin == other.asin
  end
  
  def hash
    @asin.hash
  end
  
end

class AmazonService

  OPTION = {
    "Books" => {
      :search_index => "Books",
      :sort => "daterank",
      :item_page => "1",
      :response_group => "Medium"},
    "Music" => {
      :search_index => "Music",
      :sort => "-releasedate",
      :item_page => "1",
      :response_group => "Medium"},
    "DVD" => {
      :search_index => "DVD",
      :sort => "-releasedate",
      :item_page => "1",
      :response_group => "Medium"}
    }
  ALIAS = {
    "Books" => {
      :title => :title,
      :date => :publicationdate,
      :author => :author},
    "Music" => {
      :title => :title,
      :date => :releasedate,
      :author => :artist},
    "DVD" => {
      :title => :title,
      :date => :releasedate,
      :author => :actor}
    }

  def initialize(aws_key, secret_key, target)
    @target = target
    Amazon::Ecs.options = {
      :aWS_access_key_id => aws_key,
      :aWS_secret_key => secret_key,
      :country => :jp
    }
    Amazon::Ecs.debug = false
  end

  def retrieve
    ret = []
    @target.each do |t|
      nt = {} # convert hash key: String -> Symbol
      t.each_key do |key|
        nt[:"#{key}"] = t[key]
        #nt[:"#{key}"] = CGI.escape(t[key])
      end
      op = nt.reject{|k, v| k == :keyword or k == :category}
      op.merge!(OPTION[nt[:category]])
      result = Amazon::Ecs.item_search(nt[:keyword], op)
      
      puts "#{result.items.size} items in #{t['author'] || t['artist'] || t['actor'] || t['title']}"
      result.items.each do |i|
        ret << Item.new(i, ALIAS[nt[:category]])
      end
    end
    ret.uniq
  end
  
  def future_items
    items = self.retrieve
    puts "#{items.size} items including past items."
    today = Time.now
    ret = items.delete_if {|i| i.date == nil or i.date < today}
    puts "#{ret.size} items only coming items."
    ret
  end
  
end

