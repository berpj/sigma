# Compute pageranks
class PageRank
  def initialize
    require 'pg'
    require 'redis'

    @redis = Redis.new(host: ENV['REDIS_ADDRESS'], port: ENV['REDIS_PORT'])

    @db = PGconn.connect(ENV['DB_HOSTNAME'], ENV['DB_PORT'], '', '', ENV['DB_NAME'], ENV['DB_USERNAME'], ENV['DB_PASSWORD'])

    @docs = []
  end

  def update_index
    res = @db.exec('SELECT doc_id, url, outgoing_links FROM doc_index')

    res.each do |doc|
      @redis.hsetnx("pageranks_#{doc['doc_id']}", 'pagerank', 1.0)
      @redis.hset("pageranks_#{doc['doc_id']}", 'outgoing_links', doc['outgoing_links'])
      @docs << doc
    end
  end

  def start
    @docs.each do |doc|
      result = compute(doc)
      update(doc['doc_id'], result)
    end
  end

  def close
    @redis.quit
    @db.close
  end

  private

  def backlinks(doc_id)
    backlinks = @redis.smembers("links_#{doc_id}")

    backlinks.nil? ? [] : backlinks.map(&:to_i)
  end

  def pagerank(doc_id)
    @redis.hgetall("pageranks_#{doc_id}")
  end

  def compute(doc)
    $stdout.sync = true

    damping_factor = 0.85

    backlinks = backlinks(doc['doc_id'])

    return 0.0 if backlinks.count == 1 # PR=0 if doc only has one backlink to reduce spam
    return 1.0 - damping_factor if doc['outgoing_links'] <= 1 # Minimal PR if doc doesn't have more than one outgoing link to reduce spam

    backlinks_pagerank = 0

    # PR(T1)/C(T1) + ... + PR(Tn)/C(Tn)
    backlinks.each do |backlink_doc_id|
      backlink = pagerank(backlink_doc_id)

      next if backlink.nil? || backlink['outgoing_links'].to_i.zero?

      backlinks_pagerank += backlink['pagerank'].to_f / backlink['outgoing_links'].to_f
    end

    (1.0 - damping_factor) + damping_factor * backlinks_pagerank # PR(A) = (1-d) + d (PR(T1)/C(T1) + ... + PR(Tn)/C(Tn))
  end

  def update(doc_id, result)
    @redis.hset("pageranks_#{doc_id}", 'pagerank', result)
  end
end
