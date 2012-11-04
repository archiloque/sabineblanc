# encoding: utf-8

require 'sinatra/base'
require 'active_record'
require 'sinatra/activerecord'
require 'date'

require 'nokogiri'
require 'open-uri'

class Item < ActiveRecord::Base
  validates_presence_of :url
  validates_presence_of :title
  validates_presence_of :guid
  validates_presence_of :publication_date
end

class SabineBlanc < Sinatra::Base

  register Sinatra::ActiveRecordExtension

  get '/' do
    @items = Item.order('publication_date desc')
    erb :'index.html'
  end

  FEEDS_USERS = %w(sabineblanc sabinoph alonsoblanc claireberthelemyetsabineblanc julienkirchsabineblanc sabineloguy sabineblancrc)

  def update_item(feed_item)
    guid = feed_item.at_css('guid').content
    pubDate = DateTime.parse(feed_item.at_css('pubDate').content)
    item_url = feed_item.at_css('link').content
    if (item= Item.where(:guid => guid).first)
      if item.publication_date > pubDate
        return
      else
        item.publication_date = pubDate
      end
    elsif (item= Item.where(:url => item_url).first)
      item.guid = guid
      item.publication_date = pubDate
    else
      item = Item.new
      item.guid = guid
      item.publication_date = pubDate
    end
    item.url = item_url
    item.title = feed_item.at_css('title').content
    item.tags =
        feed_item.
            css('category').
            collect { |c| c.content }.
            join(',')
    if (image = Nokogiri::XML(feed_item.at_xpath('content:encoded').content).at_css('img'))
      item.image = image.attr('src')
    end
    item.save!
  end

  get '/update' do
    FEEDS_USERS.each do |feed_user|
      Nokogiri::XML(open("http://owni.fr/author/#{feed_user}/feed/")).css('item').each do |feed_item|
        update_item(feed_item)
      end
    end
  end

  def scrape_article(article_url)
    p article_url
    if Item.where(:url => article_url).exists?
      return
    end
    article = Nokogiri::HTML(open(article_url).read)
    article.encoding = 'utf-8'
    item = Item.new

    item.url = article_url
    item.guid = article_url
    item.title = article.
        at_css('head').
        at_css('title').
        content
    item.tags = article.
        css('.tags a').
        collect { |a| a.content.strip }.
        select { |t| !t.blank? }.
        join(',')
    if item.tags.blank?
      item.tags = nil
    end

    monthes = {
        'janvier' => 1,
        'février' => 2,
        'mars' => 3,
        'avril' => 4,
        'mai' => 5,
        'juin' => 6,
        'juillet' => 7,
        'août' => 8,
        'septembre' => 9,
        'octobre' => 10,
        'novembre' => 11,
        'décembre' => 12}

    date_string = article.
        at_css('.author .date').
        content

    if (parsed_date = /\ALe (\d+) (\S+) (\d+)\z/.match(date_string))
    item.publication_date =
        DateTime.new(
            parsed_date[3].to_i,
            monthes[parsed_date[2]],
            parsed_date[1].to_i,
        )
    elsif (parsed_date = /\ALe (\d+)\/(\d+)\/(\d+)\z/.match(date_string))
      item.publication_date =
          DateTime.new(
              parsed_date[3].to_i,
              parsed_date[2].to_i,
              parsed_date[1].to_i,
          )
    else
      return 'Fail'
    end
    if (image = article.
        at_css('head').
        at_xpath('meta[@property="og:image"]'))
      item.image = image.attr('content')
    end
    item.save!
    'ok'
  end

  get '/scrape_old' do
    FEEDS_USERS.each do |feed_user|
      next_page = true
      current_page = 0
      while next_page
        current_page += 1
        next_page = false
        url = "http://owni.fr/author/#{feed_user}/page/#{current_page}/"
        current_author_page = Nokogiri::HTML(open("http://owni.fr/author/#{feed_user}/page/#{current_page}/"), url, 'UTF-8')
        current_author_page.css('.blocMain .entry_title').each do |entry|
          entry_url = entry.at_css('a').attr('href')
          scrape_article(entry_url)
          next_page = true
        end
      end
    end
    'ok'
  end

end