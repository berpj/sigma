#!/usr/bin/ruby

# Compute pageranks
class PageRank
  @conn = nil

  @docs = []

  def initialize
    require 'pg'
    require 'redis'

    @redis = Redis.new(host: ENV['REDIS_ADDRESS'], port: ENV['REDIS_PORT'])

    @conn = PGconn.connect(ENV['DB_HOSTNAME'], ENV['DB_PORT'], '', '', ENV['DB_NAME'], ENV['DB_USERNAME'], ENV['DB_PASSWORD'])
  end

  def get_backlinks(doc_id)
    backlinks = @redis.smembers("links_#{doc_id}")

    backlinks.nil? ? [] : backlinks.map(&:to_i)
  end

  def get_pagerank(doc_id)
    @redis.hgetall("pageranks_#{doc_id}")
  end

  def compute_pagerank(doc)
    $stdout.sync = true

    damping_factor = 0.85

    backlinks = get_backlinks(doc['doc_id'])

    backlinks_pagerank = 0

    # PR(T1)/C(T1) + ... + PR(Tn)/C(Tn)\
    backlinks.each do |backlink_doc_id|
      backlink = get_pagerank(backlink_doc_id)

      next if backlink.nil? || backlink['outgoing_links'].to_i.zero?

      backlinks_pagerank += backlink['pagerank'].to_f / backlink['outgoing_links'].to_f
    end

    # PR(A) = (1-d) + d (PR(T1)/C(T1) + ... + PR(Tn)/C(Tn))
    (1 - damping_factor) + damping_factor * backlinks_pagerank
  end

  def update_pageranks_index
    docs = @conn.exec('SELECT doc_id, url, outgoing_links FROM doc_index')

    docs.each do |doc|
      @redis.hsetnx("pageranks_#{doc['doc_id']}", 'pagerank', 1.0)
      @redis.hset("pageranks_#{doc['doc_id']}", 'outgoing_links', doc['outgoing_links'])
    end

    docs
  end

  def update_pagerank(doc_id, result)
    @redis.hset("pageranks_#{doc_id}", 'pagerank', result)
  end
end

$stdout.sync = true

pagerank = PageRank.new

loop do
  docs = pagerank.update_pageranks_index

  docs.each do |doc|
    result = pagerank.compute_pagerank(doc)
    pagerank.update_pagerank(doc['doc_id'], result)
  end

  sleep(0.1)
end
