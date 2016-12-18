require_relative 'resolv'
require_relative 'parse'

# Get new documents from the repository, parse them, index them
class Index
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

    @db.prepare('update_doc_in_doc_index', 'update doc_index set title=$1, description=$2, lang=$3, outgoing_links=$4, parsed_at=$5, status=$6, url=$7 WHERE doc_id=$8')
    @db.prepare('insert_doc_into_doc_index', 'INSERT INTO doc_index (url) VALUES ($1) RETURNING *')
    @db.prepare('delete_from_errors', 'DELETE FROM errors WHERE doc_id=$1')
    @db.prepare('delete_from_doc_index', 'DELETE FROM doc_index WHERE doc_id=$1')
    @db.prepare('select_timedout_in_doc_index', 'SELECT doc_id, url, status FROM doc_index WHERE status=\'WIP2\' AND sent_to_crawler_at<$1 LIMIT 512')

    @docs_to_index = []
  end

  def set_docs_to_index
    res = @db.exec('SELECT doc_id, url, content
      FROM repository
      WHERE doc_id IN (
        SELECT doc_id
        FROM doc_index
        WHERE status=\'WIP\'
      )
      LIMIT 8')

    res.each do |doc|
      @docs_to_index << { doc_id: doc['doc_id'], url: doc['url'], content: doc['content'] }
    end
  end

  def start
    resolv = Resolv.new

    @docs_to_index.each do |doc|
      parse = Parse.new(doc)

      parse.start
      urls = parse.urls
      title = parse.title
      description = parse.description
      lang = parse.lang
      words = parse.words
      outgoing_links = urls.count

      update_index(doc[:doc_id], title, description, lang, outgoing_links, Time.now.to_i, doc[:url]) # SQL update
      send_doc_to_pageranker(doc[:doc_id], outgoing_links)
      add_to_words(words, doc[:doc_id]) # Redis

      urls.each do |url|
        new_doc_id = resolv.doc_id(url) # Is this URL already in doc_index? (Redis)

        unless new_doc_id # If this is a new URL...
          new_doc_id = add_to_index(url) # Add to doc_index (SQL insert)
          resolv.add(url, new_doc_id) # Add to URLs index (Redis)
        end

        add_to_links(doc[:doc_id], new_doc_id) # Add to links index for Pageranker (Redis)
      end
    end

    resolv.close
  end

  def delete_error_docs
    res1 = @db.exec('SELECT * FROM errors WHERE error!=200 AND error IS NOT NULL LIMIT 512')

    res2 = @db.exec_prepared('select_timedout_in_doc_index', [Time.now.to_i - 20 * 60])

    docs = []

    res1.each { |doc| docs << doc }
    res2.each { |doc| docs << doc }

    docs.each do |doc|
      @db.exec_prepared('delete_from_errors', [doc['doc_id']])
      @db.exec_prepared('delete_from_doc_index', [doc['doc_id']])
      # To do: delete from pageranks
    end
  end

  def close
    @redis.quit
    @db.close
  end

  private

  def update_index(doc_id, title, description, lang, outgoing_links, parsed_at, url)
    @db.exec_prepared('update_doc_in_doc_index', [title, description, lang, outgoing_links, parsed_at, 'OK', url, doc_id])
  end

  def send_doc_to_pageranker(doc_id, outgoing_links)
    require 'json'

    begin
      queue = @sqs.queues.named('search_engine_docs_to_pagerank')
    rescue AWS::SQS::Errors::NonExistentQueue
      @sqs.queues.create('search_engine_docs_to_pagerank')
      queue = @sqs.queues.named('search_engine_docs_to_pagerank')
    end

    queue = @sqs.queues.named('search_engine_docs_to_pagerank')

    message = { doc_id: doc_id, outgoing_links: outgoing_links }

    queue.send_message(message.to_json)
  end

  def add_to_index(url)
    doc = @db.exec_prepared('insert_doc_into_doc_index', [url])
    doc[0]['doc_id']
  end

  def add_to_links(doc_id_from, doc_id_to)
    @redis.sadd("links_#{doc_id_to}", doc_id_from)
  end

  def add_to_words(words, doc_id)
    words.each do |word|
      @redis.zadd("words_#{word[:word]}", (2 * word[:quality] + word[:position]) / 3.0, doc_id, nx: true)
    end
  end
end
