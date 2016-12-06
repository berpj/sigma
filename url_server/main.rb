#!/usr/bin/ruby

# Serves URLs to crawlers using a queue
class UrlServer
  @conn = nil
  @sqs = nil

  def initialize
    require 'pg'
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

    @conn = PGconn.connect(ENV['DB_HOSTNAME'], ENV['DB_PORT'], '', '', ENV['DB_NAME'], ENV['DB_USERNAME'], ENV['DB_PASSWORD'])

    @conn.prepare('update_status_in_doc_index', 'UPDATE doc_index SET status=$1, sent_to_crawler_at=$2 WHERE doc_id=$3')
    @conn.prepare('select_timedout_in_doc_index', 'SELECT doc_id, url, status FROM doc_index WHERE status=\'WIP\' AND (sent_to_crawler_at<$1 OR sent_to_crawler_at IS NULL) LIMIT 128')
  end

  def new_docs_to_crawl
    res = @conn.exec('SELECT DISTINCT ON (CONCAT(split_part(split_part(split_part(url, \'//\', 2), \'/\', 1), \'.\', 1), split_part(split_part(split_part(url, \'//\', 2), \'/\', 1), \'.\', 2))) doc_id, url, status FROM doc_index WHERE parsed_at IS NULL AND status IS NULL LIMIT 384')

    docs = []

    res.each do |doc|
      docs << { doc_id: doc['doc_id'], url: doc['url'], status: doc['status'] }
    end

    docs
  end

  def docs_to_recrawl
    res = @conn.exec_prepared('select_timedout_in_doc_index', [Time.now.to_i - 20 * 60])

    docs = []

    res.each do |doc|
      docs << { doc_id: doc['doc_id'], url: doc['url'], status: doc['status'] }
    end

    docs
  end

  def send_docs_to_crawler(docs)
    require 'json'

    begin
      queue = @sqs.queues.named('search_engine_docs_to_crawl')
    rescue AWS::SQS::Errors::NonExistentQueue
      @sqs.queues.create('search_engine_docs_to_crawl')
      queue = @sqs.queues.named('search_engine_docs_to_crawl')
    end

    queue = @sqs.queues.named('search_engine_docs_to_crawl')

    approximate_number_of_messages = queue.approximate_number_of_messages

    i = 0
    docs.each do |doc|
      break if approximate_number_of_messages + i > 512

      queue.send_message(doc.to_json)

      if doc[:status] == 'WIP'
        @conn.exec_prepared('update_status_in_doc_index', ['WIP2', Time.now.to_i, doc[:doc_id]])
      else
        @conn.exec_prepared('update_status_in_doc_index', ['WIP', Time.now.to_i, doc[:doc_id]])
      end

      i += 1
    end
  end
end

$stdout.sync = true

url_server = UrlServer.new

loop do
  docs = url_server.new_docs_to_crawl + url_server.docs_to_recrawl
  url_server.send_docs_to_crawler(docs)

  sleep(0.1)
end
