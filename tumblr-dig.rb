#!/usr/bin/ruby
# vim: set fileencoding=utf-8 :

require 'find'
require 'json'
require 'oauth'
require 'oauth/consumer'
require 'open-uri'
require 'optparse'
require 'pathname'
require 'pp'
require 'shellwords'
require 'tumblr_client'


class Options
  attr_reader :offset, :posts, :oauth_config

  def initialize (argv)
    init
    parse(argv)
  end

  private
  def init
    @offset = 0
    @posts = 100
    @oauth_config = 'oauth_config.json'
  end

  def parse (argv)
    OptionParser.new do |opt|
      opt.on('--posts N_POSTS',  'Number of posts') {|v| @posts = v.to_i }
      opt.on('--offset OFFSET',  'Offset (0 origin)') {|v| @offset = v.to_i }
      opt.on('--oauth-config FILEPATH',  'OAuth config filepath') {|v| @oauth_config = Pathname(v) }
      opt.parse!(argv)
    end
  end
end


class OAuthConfig < Struct.new(:consumer_key, :consumer_secret, :access_token, :access_secret)

  def self.load_from_file(filepath)
    if filepath.file?
      json = JSON.load(File.read(filepath))
      consumer_key = json['consumer_key']
      consumer_secret = json['consumer_secret']
      access_token = json['access_token']
      access_secret = json['access_secret']
      if access_token and access_secret and consumer_key and consumer_secret
        return OAuthConfig.new(consumer_key, consumer_secret, access_token, access_secret)
      end
    end

    print('Consumer key: ')
    consumer_key = gets.chomp
    print('Consumer secret: ')
    consumer_secret = gets.chomp

    consumer = OAuth::Consumer.new(consumer_key, consumer_secret, {
      :site => "https://www.tumblr.com",
      :request_token_path => '/oauth/request_token',
      :authorize_path     => '/oauth/authorize',
      :access_token_path  => '/oauth/access_token',
    })

    request_token = consumer.get_request_token(:exclude_callback => true)

    puts('Open: ' + request_token.authorize_url)
    print('Input oauth_verifier: ')

    verifier = gets.strip
    access_token = request_token.get_access_token(:oauth_verifier => verifier)

    json = {
      :consumer_key => consumer_key,
      :consumer_secret => consumer_secret,
      :access_token => access_token.token,
      :access_secret => access_token.secret
    }
    File.write(filepath, JSON.dump(json))

    OAuthConfig.load_from_file(filepath)
  end
end


class App
  LIMIT = 20
  INTERVAL = 10

  def initialize (oauth)
    Tumblr.configure do |c|
      c.consumer_key = oauth.consumer_key
      c.consumer_secret = oauth.consumer_secret
      c.oauth_token = oauth.access_token
      c.oauth_token_secret = oauth.access_secret
    end

    @client = Tumblr::Client.new

    @user_name = @client.info.dig('user', 'name')
  end

  def collect(offset: 0, posts: 100, target: :dashboard)
    STDERR.puts("[collect] offset: #{offset}, posts: #{posts}, target: #{target}")

    collected_posts = 0
    next_offset = offset
    fetched_ids = {}

    while collected_posts < posts
      sleep(INTERVAL) if collected_posts > 0

      STDERR.puts("[fetch] next_offset: #{next_offset}")
      urls, fetched_posts = case target
                           when :dashboard
                             fetch_dashboard(offset: next_offset, fetched_ids: fetched_ids)
                           end
      urls.each {|it| STDOUT.puts(it) }
      STDOUT.flush

      next_offset += fetched_posts
      collected_posts += fetched_posts

      STDERR.puts("[fetched] fetched_posts: #{fetched_posts}, collected_posts: #{collected_posts}")
    end
  end

  # [<URLs>, <Number of posts>]
  def fetch_dashboard(offset: 0, fetched_ids: nil)
    posts = @client.dashboard(:type => 'photo', :limit => LIMIT, :offset => offset)['posts']

    urls = posts.map do |post|
      if fetched_ids
        next [] if fetched_ids[post['id']]
        fetched_ids[post['id']] = true
      end

      post['photos'].map do |photo|
        photo.dig('original_size', 'url')
      end
    end.flatten

    [urls, posts.size]
  end
end


if __FILE__ == $0
  option = Options.new(ARGV)

  oauth_config = OAuthConfig.load_from_file(option.oauth_config)

  app = App.new(oauth_config)
  app.collect(posts: option.posts, offset: option.offset)
end
