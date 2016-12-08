# Crawls web pages
class Crawl
  def initialize()
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

    @db = PGconn.connect(ENV['DB_HOSTNAME'], ENV['DB_PORT'], '', '', ENV['DB_NAME'], ENV['DB_USERNAME'], ENV['DB_PASSWORD'])
    @db.prepare('insert_doc_into_repository', 'insert into repository (doc_id, url, content) values ($1, $2, $3)')
    @db.prepare('insert_doc_into_errors', 'insert into errors (doc_id, url, error, details) values ($1, $2, $3, $4)')

    @docs_to_crawl = []
  end

  def set_docs_to_crawl
    begin
      queue = @sqs.queues.named('search_engine_docs_to_crawl')
    rescue AWS::SQS::Errors::NonExistentQueue
      @sqs.queues.create('search_engine_docs_to_crawl')
      queue = @sqs.queues.named('search_engine_docs_to_crawl')
    end

    messages = queue.receive_messages(limit: 10)
    return if messages.nil?

    messages.each do |message|
      doc = JSON.parse(message.body)
      doc['url'] = URI.escape(doc['url'])

      @docs_to_crawl << doc unless doc.nil? || doc['url'].nil?

      message.delete
    end
  end

  def start
    @docs_to_crawl.each do |doc|
      url, content, code, error_details = crawl_url doc['url']

      if content.nil? || url.nil? || code != 200
        add_to_errors(doc['doc_id'], url, code, error_details)
      else
        add_to_repository(doc['doc_id'], url, content)
      end
    end
  end

  def close
    @db.close
  end

  private

  def crawl_url(url, redirect_limit = 10)
    require 'net/http'
    require 'openssl'

    $stdout.sync = true

    begin
      raise ArgumentError, 'HTTP redirect too deep' if redirect_limit.zero?
      url = URI.parse(url)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = (url.scheme == 'https')

      head_response = http.head url.path.empty? ? '/' : url.path

      raise Net::HTTPBadResponse, 'No head receive' unless head_response['content-type']
      raise Net::HTTPBadResponse, "Response not HTML but #{head_response['content-type']}" unless head_response['content-type'].start_with?('text/html', 'application/xhtml+xml')

      req = Net::HTTP::Get.new(url.request_uri)

      response = http.request(req)

      case response
      when Net::HTTPSuccess
        raise Net::HTTPBadResponse, 'Body nil' if response.body.nil?
        return URI.unescape(url.to_s.force_encoding("UTF-8")), response.body.force_encoding("UTF-8"), response.code.to_i, nil
      when Net::HTTPRedirection
        return crawl_url(response.header['location'], redirect_limit - 1)
      else
        raise Net::HTTPBadResponse, 'HTTP bad response'
      end

    rescue  NoMethodError, SocketError, OpenSSL::SSL::SSLError, ArgumentError,
            Errno::ECONNREFUSED, Timeout::Error, Errno::EINVAL,
            Errno::ECONNRESET, EOFError, Net::HTTPBadResponse,
            Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
      puts "#{url} #{e.inspect}"
      code = defined? response && !response.nil? ? response.code : 0
      return URI.unescape(url.to_s.force_encoding("UTF-8")), nil, code.to_i, e.class
    end
  end

  def add_to_repository(doc_id, url, content)
    @db.exec_prepared('insert_doc_into_repository', [doc_id, url, content])
  end

  def add_to_errors(doc_id, url, code, error_details)
    @db.exec_prepared('insert_doc_into_errors', [doc_id, url, code, error_details])
  end
end
