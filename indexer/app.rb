#!/usr/bin/ruby

# Resolve URLS
class Resolver
  def initialize
    require 'redis'

    @redis = Redis.new(host: ENV['REDIS_ADDRESS'], port: ENV['REDIS_PORT'])
  end

  def add_to_urls(url, doc_id)
    @redis.set("urls_#{url}", doc_id)
  end

  def get_doc_id(url)
    @redis.get("urls_#{url}")
  end
end

# Get new documents from the repository, parse them, index them
class Indexer
  @conn = nil

  def initialize
    require 'pg'
    require 'redis'

    @redis = Redis.new(host: ENV['REDIS_ADDRESS'], port: ENV['REDIS_PORT'])

    db_hostname = ENV['DB_HOSTNAME']
    db_username = ENV['DB_USERNAME']
    db_password = ENV['DB_PASSWORD']
    db_name = ENV['DB_NAME']
    db_port = ENV['DB_PORT']

    @conn = PGconn.connect(db_hostname, db_port, '', '', db_name, db_username, db_password)

    @conn.prepare('update_doc_in_doc_index', 'update doc_index set title=$1::bytea, outgoing_links=$2, parsed_at=$3, status=$4, url=$5 WHERE doc_id=$6')
    @conn.prepare('insert_doc_into_doc_index', 'INSERT INTO doc_index (url) VALUES ($1) RETURNING *')

    @conn.prepare('delete_from_errors', 'DELETE FROM errors WHERE doc_id=$1')
    @conn.prepare('delete_from_doc_index', 'DELETE FROM doc_index WHERE doc_id=$1')

    @conn.prepare('select_timedout_in_doc_index', 'SELECT doc_id, url, status FROM doc_index WHERE status=\'WIP2\' AND sent_to_crawler_at<$1 LIMIT 512')
  end

  def get_new_docs_from_repository
    res = @conn.exec('SELECT doc_id, url, encode(content, \'escape\') AS content
      FROM repository
      WHERE doc_id IN (
        SELECT doc_id
        FROM doc_index
        WHERE status=\'WIP\'
      )
      LIMIT 8')

    docs = []

    res.each do |doc|
      docs << { doc_id: doc['doc_id'], url: doc['url'], content: doc['content'] }
    end

    docs
  end

  def parse_links(doc)
    require 'nokogiri'

    title = doc[:content].match(/<title>(.*?)<\/title>/)
    title = (title) ? title[1] : ''

    html = Nokogiri::HTML(doc[:content])

    hrefs = []

    html.css("a").each do |a|
      hrefs << a.attr('href').strip if ! a.attr('href').nil? &&
      ! a.attr('href').empty? && (a.attr('href').start_with?('http')
      || a.attr('href').start_with?('/')) && ! a.attr('href').match(/\s/)
      && a.attr('href').ascii_only?
    end

    begin
      urls = []
      hrefs.each do |href|
        urls << URI.join(doc[:url], href).to_s
      end
    rescue URI::InvalidURIError
      return title, []
    end

    # Drop query strings and # part
    urls.map! do |url|
      url.split('#')[0]
    end

    return title, urls.uniq.first(100)
  end

  def parse_words(title, doc)
    require 'nokogiri'
    require 'i18n'

    I18n.config.available_locales = :en

    doc = Nokogiri::HTML("#{title} #{doc[:content]}")

    doc.css('head, script, link').each { |node| node.remove unless node.nil? } # Remove useless html nodes
    text = doc.css('body').text.tr("\n", ' ').downcase # Normalize text
    words = text.split(/\W+/) # Text to array of words

    result = []
    words_count = words.count
    position = 0
    words.each do |word|
      result << { word: word, position: (position / words_count.to_f).round(5) }
      position += 1
    end

    result
  end

  def update_index(doc_id, title, outgoing_links, parsed_at, url)
    title = @conn.escape_bytea(title) unless title.nil?

    @conn.exec_prepared('update_doc_in_doc_index', [title, outgoing_links, parsed_at, 'OK', url, doc_id])

    doc_id
  end

  def add_to_index(url)
    doc = @conn.exec_prepared('insert_doc_into_doc_index', [url])
    doc[0]['doc_id']
  end

  def add_to_links(doc_id_from, doc_id_to)
    @redis.sadd("links_#{doc_id_to}", doc_id_from)
  end

  def add_to_words(words, doc_id)
    words.each do |word|
      @redis.zadd("words_#{word[:word]}", word[:position], doc_id)
    end
  end

  def delete_error_docs
    $stdout.sync = true

    res1 = @conn.exec('SELECT * FROM errors WHERE error!=200 AND error IS NOT NULL LIMIT 512')

    res2 = @conn.exec_prepared('select_timedout_in_doc_index', [Time.now.to_i - 20 * 60])

    docs = []

    res1.each { |doc| docs << doc }
    res2.each { |doc| docs << doc }

    docs.each do |doc|
      @conn.exec_prepared('delete_from_errors', [doc['doc_id']])
      @conn.exec_prepared('delete_from_doc_index', [doc['doc_id']])
      # To do: delete from pageranks
    end
  end
end

$stdout.sync = true

require 'work_queue'

indexer = Indexer.new
resolver = Resolver.new

loop do
  indexer.delete_error_docs

  docs = indexer.get_new_docs_from_repository

  docs.each do |doc|
    tmp_indexer = Indexer.new

    title, urls = indexer.parse_links(doc)
    tmp_indexer.update_index(doc[:doc_id], title, urls.count, Time.now.to_i, doc[:url]) # SQL update

    words = indexer.parse_words(title, doc)
    indexer.add_to_words(words, doc[:doc_id]) # Redis

    urls.each do |url|
      doc_id = resolver.get_doc_id(url) # Redis
      unless doc_id
        new_doc_id = tmp_indexer.add_to_index(url) # SQL insert
        resolver.add_to_urls(url, new_doc_id) # Redis
        indexer.add_to_links(doc[:doc_id], new_doc_id) # Redis
      end
    end
  end

  sleep(0.1)
end
