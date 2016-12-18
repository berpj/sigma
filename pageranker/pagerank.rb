# Compute pageranks
class PageRank
  def initialize
    require 'pg'
    require 'redis'
    require 'aws-sdk-v1'

    AWS.config(
      access_key_id: ENV['AWS_ACCESS_ID'],
      secret_access_key: ENV['AWS_ACCESS_KEY'],
      region: ENV['AWS_REGION'],
      sqs_port: ENV['SQS_PORT'],
      use_ssl: ENV['SQS_SECURE'] != 'False',
      sqs_endpoint: ENV['SQS_ADDRESS']
    )

    @sqs = AWS::SQS.new

    @redis = Redis.new(host: ENV['REDIS_ADDRESS'], port: ENV['REDIS_PORT'])

    @db = PGconn.connect(ENV['DB_HOSTNAME'], ENV['DB_PORT'], '', '', ENV['DB_NAME'], ENV['DB_USERNAME'], ENV['DB_PASSWORD'])

    @docs_to_index = []
  end

  def set_docs_to_index
    begin
      queue = @sqs.queues.named('search_engine_docs_to_pagerank')
    rescue AWS::SQS::Errors::NonExistentQueue
      @sqs.queues.create('search_engine_docs_to_pagerank')
      queue = @sqs.queues.named('search_engine_docs_to_pagerank')
    end

    messages = queue.receive_messages(limit: 10)
    return if messages.nil?

    messages.each do |message|
      doc = JSON.parse(message.body)
      @docs_to_index << doc unless doc.nil? || doc['doc_id'].nil?

      message.delete
    end
  end

  def update_index
    @docs_to_index.each do |doc|
      @redis.hsetnx("pageranks_#{doc['doc_id']}", 'pagerank', 1.0)
      @redis.hset("pageranks_#{doc['doc_id']}", 'outgoing_links', doc['outgoing_links'])
    end
  end

  def start
    @redis.scan_each(match: 'pageranks_*') do |key|
      hash = @redis.hgetall(key)
      doc =  { 'doc_id' => key.split('_')[1], 'pagerank' => hash['pagerank'].to_f, 'outgoing_links' => hash['outgoing_links'].to_i }

      result = compute(doc)
      update(doc['doc_id'], result, true) # Tmp save
    end

    @redis.scan_each(match: 'tmp_pageranks_*') do |key|
      hash = @redis.hgetall(key)
      doc =  { 'doc_id' => key.split('_')[2], 'pagerank' => hash['pagerank'].to_f }

      update(doc['doc_id'], doc['pagerank'], false) # Definitive save
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

  def update(doc_id, result, tmp)
    if tmp
      @redis.hset("tmp_pageranks_#{doc_id}", 'pagerank', result)
    else
      @redis.hset("pageranks_#{doc_id}", 'pagerank', result)
    end
  end
end
