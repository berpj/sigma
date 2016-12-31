# Serves URLs to crawlers using a queue
class ServeUrls
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

    @db.prepare('update_status_in_doc_index', 'UPDATE doc_index SET status=$1, sent_to_crawler_at=$2 WHERE doc_id=$3')
    @db.prepare('select_timedout_in_doc_index', 'SELECT doc_id, url, status FROM doc_index WHERE status=\'WIP\' AND (sent_to_crawler_at<$1 OR sent_to_crawler_at IS NULL) LIMIT 128')

    @new_docs = []
    @docs_to_recrawl = []
  end

  def update_new_docs_to_crawl
    res = @db.exec('SELECT DISTINCT ON (CONCAT(split_part(split_part(split_part(url, \'//\', 2), \'/\', 1), \'.\', 1), split_part(split_part(split_part(url, \'//\', 2), \'/\', 1), \'.\', 2))) doc_id, url, status FROM doc_index WHERE parsed_at IS NULL AND status IS NULL LIMIT 384')

    res.each do |doc|
      domain = extract_domain(doc['url'])
      next unless domain
      delta = Time.now.to_i - last_crawled_time(domain)

      # Crawl this url if this domain was not crawled during the last 60 seconds
      @new_docs << { doc_id: doc['doc_id'], url: doc['url'], domain: domain, status: doc['status'] } if delta >= 90
    end
  end

  def update_docs_to_recrawl
    res = @db.exec_prepared('select_timedout_in_doc_index', [Time.now.to_i - 20 * 60])

    res.each do |doc|
      @docs_to_recrawl << { doc_id: doc['doc_id'], url: doc['url'], status: doc['status'] }
    end
  end

  def send_docs_to_crawler
    require 'json'

    docs = @new_docs + @docs_to_recrawl

    begin
      queue = @sqs.queues.named('search_engine_docs_to_crawl')
    rescue AWS::SQS::Errors::NonExistentQueue
      @sqs.queues.create('search_engine_docs_to_crawl')
      queue = @sqs.queues.named('search_engine_docs_to_crawl')
    end

    approximate_number_of_messages = queue.approximate_number_of_messages

    i = 0
    docs.each do |doc|
      break if approximate_number_of_messages + i > 512

      queue.send_message(doc.to_json)

      update_domain_index(doc[:domain])

      if doc[:status] == 'WIP'
        @db.exec_prepared('update_status_in_doc_index', ['WIP2', Time.now.to_i, doc[:doc_id]])
      else
        @db.exec_prepared('update_status_in_doc_index', ['WIP', Time.now.to_i, doc[:doc_id]])
      end

      i += 1
    end
  end

  def close
    @db.close
  end

  private

    def last_crawled_time(domain)
      timestamp = @redis.get("domains_#{domain}")

      timestamp.to_i
    end

    def extract_domain(url)
      require 'uri/http'

      uri = URI.parse(URI.escape(url))

      return nil unless uri.host

      uri.host.split(".")[-2,2].join(".")
    end

    def update_domain_index(domain)
      @redis.set("domains_#{domain}", Time.now.to_i)
    end
end
