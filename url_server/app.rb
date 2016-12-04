#!/usr/bin/ruby

class UrlServer

  @conn = nil

  def initialize
    require 'pg'

    db_hostname = ENV['DB_HOSTNAME']
    db_username = ENV['DB_USERNAME']
    db_password = ENV['DB_PASSWORD']
    db_name = ENV['DB_NAME']
    db_port = ENV['DB_PORT']

    @conn = PGconn.connect(db_hostname, db_port, '', '', db_name, db_username, db_password)

    @conn.prepare('update_status_in_doc_index', 'UPDATE doc_index SET status=$1, sent_to_crawler_at=$2 WHERE doc_id=$3')

    @conn.prepare('select_timedout_in_doc_index', 'SELECT doc_id, url, status FROM doc_index WHERE status=\'WIP\' AND (sent_to_crawler_at<$1 OR sent_to_crawler_at IS NULL) LIMIT 128')
  end

  def get_new_docs_to_crawl
    res = @conn.exec('SELECT DISTINCT ON (CONCAT(split_part(split_part(split_part(url, \'//\', 2), \'/\', 1), \'.\', 1), split_part(split_part(split_part(url, \'//\', 2), \'/\', 1), \'.\', 2))) doc_id, url, status FROM doc_index WHERE parsed_at IS NULL AND status IS NULL LIMIT 384')

    docs = Array.new

    res.each do |doc|
      docs << { :doc_id => doc['doc_id'], :url => doc['url'], :status => doc['status'] }
    end

    return docs
  end

  def get_docs_to_recrawl
    res = @conn.exec_prepared('select_timedout_in_doc_index', [ Time.now.to_i - 20 * 60 ])

    docs = Array.new

    res.each do |doc|
      docs << { :doc_id => doc['doc_id'], :url => doc['url'], :status => doc['status'] }
    end

    return docs
  end

  def send_docs_to_crawler(docs)
    require 'aws-sdk-v1'
    require 'json'

    AWS.config(
      :access_key_id => ENV['AWS_ACCESS_ID'],
      :secret_access_key => ENV['AWS_ACCESS_KEY'],
      :region => ENV['AWS_REGION'],
      :sqs_port => ENV['SQS_PORT'],
      :use_ssl => ENV['SQS_SECURE'] != 'False',
      :sqs_endpoint => ENV['SQS_ADDRESS']
    )

    sqs = AWS::SQS.new

    begin
      queue = sqs.queues.named('search_engine_docs_to_crawl')
    rescue AWS::SQS::Errors::NonExistentQueue => e
      sqs.queues.create('search_engine_docs_to_crawl')
      queue = sqs.queues.named('search_engine_docs_to_crawl')
    end

    queue = sqs.queues.named('search_engine_docs_to_crawl')

    approximate_number_of_messages = queue.approximate_number_of_messages

    i = 0
    docs.each do |doc|
      break if approximate_number_of_messages + i > 512

      queue.send_message(doc.to_json)

      if doc[:status] == 'WIP'
        @conn.exec_prepared('update_status_in_doc_index', [ 'WIP2', Time.now.to_i, doc[:doc_id] ])
      else
        @conn.exec_prepared('update_status_in_doc_index', [ 'WIP', Time.now.to_i, doc[:doc_id] ])
      end

      i += 1
    end
  end
end

$stdout.sync = true

url_server = UrlServer.new

while true do
  docs = url_server.get_new_docs_to_crawl + url_server.get_docs_to_recrawl
  url_server.send_docs_to_crawler(docs)

  sleep(0.1)
end
