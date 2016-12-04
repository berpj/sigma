#!/usr/bin/ruby

class Crawler

  $stdout.sync = true
  @conn = nil

  def initialize
    require 'pg'

    db_hostname = ENV['DB_HOSTNAME']
    db_username = ENV['DB_USERNAME']
    db_password = ENV['DB_PASSWORD']
    db_name = ENV['DB_NAME']
    db_port = ENV['DB_PORT']

    @conn = PGconn.connect(db_hostname, db_port, '', '', db_name, db_username, db_password)

    @conn.prepare('insert_doc_into_repository', 'insert into repository (doc_id, url, content) values ($1, $2, $3::bytea)')
    @conn.prepare('insert_doc_into_errors', 'insert into errors (doc_id, url, error, details) values ($1, $2, $3, $4)')
  end

  def get_docs_to_crawl
    require 'aws-sdk-v1'

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

    messages = queue.receive_messages(limit: 8)

    return nil if messages.nil?

    messages.each do |message|
      message.delete
    end

    messages
  end

  def crawl_page(url, redirect_limit = 10)
    require 'net/http'
    require 'openssl'

    begin
      raise ArgumentError, 'HTTP redirect too deep' if redirect_limit == 0

      url = URI.parse(url)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = (url.scheme == "https")

      head_response = http.head((url.path.empty?) ? ('/') : (url.path))

      raise Net::HTTPBadResponse, "No head receive" unless head_response['content-type']
      raise Net::HTTPBadResponse, "Response not HTML but #{head_response['content-type']}" unless head_response['content-type'].start_with?('text/html') || head_response['content-type'].start_with?('application/xhtml+xml')

      req = Net::HTTP::Get.new(url.request_uri)

      response = http.request(req)

      case response
      when Net::HTTPSuccess
        raise Net::HTTPBadResponse, 'Body nil' if response.body.nil?

        return url, response.body, response.code.to_i, nil
      when Net::HTTPRedirection
        return crawl_page(response.header['location'], redirect_limit - 1)
      else
        raise Net::HTTPBadResponse, 'HTTP bad response'
      end

    rescue NoMethodError, SocketError, OpenSSL::SSL::SSLError, ArgumentError, Errno::ECONNREFUSED, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
      puts e.inspect
      code = (defined? response && response != nil) ? (response.code) : (0)
      return url, nil, code.to_i, e.class
    end
  end

  def add_to_repository(doc_id, url, content)
    content = @conn.escape_bytea(content)

    @conn.exec_prepared('insert_doc_into_repository', [ doc_id, url, content ])
  end

  def add_to_errors(doc_id, url, code, error_details)
    @conn.exec_prepared('insert_doc_into_errors', [ doc_id, url, code, error_details ])
  end
end

$stdout.sync = true

require 'work_queue'

crawler = Crawler.new

while true do
  messages = crawler.get_docs_to_crawl + crawler.get_docs_to_crawl

  wq = WorkQueue.new 8

  messages.each do |message|
    doc = JSON.load(message.body)

    wq.enqueue_b do
      tmp_crawler = Crawler.new

      unless doc.nil? || doc['url'].nil?
        url, content, code, error_details = tmp_crawler.crawl_page(doc['url'])

        if content.nil? || url.nil? || code != 200
          tmp_crawler.add_to_errors(doc['doc_id'], url, code, error_details)
        else
          tmp_crawler.add_to_repository(doc['doc_id'], url, content)
        end
      end
    end
  end

  wq.join

  sleep(1.5)
end
