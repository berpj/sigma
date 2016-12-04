# SQS

require 'aws-sdk'

AWS.config(
  :access_key_id => ENV['AWS_ACCESS_ID'],
  :secret_access_key => ENV['AWS_ACCESS_KEY'],
  :region => ENV['AWS_REGION']
)

sqs = AWS::SQS.new

queue = sqs.queues.named('search_engine_docs_to_crawl')

queue.purge_queue_request()


# PostgreSQL

require 'pg'

db_hostname = ENV['DB_HOSTNAME']
db_username = ENV['DB_USERNAME']
db_password = ENV['DB_PASSWORD']
db_name = ENV['DB_NAME']
db_port = ENV['DB_PORT']

@conn = PGconn.connect(db_hostname, db_port, '', '', db_name, db_username, db_password)

@conn.exec('TRUNCATE TABLE doc_index RESTART IDENTITY')
@conn.exec('TRUNCATE TABLE repository RESTART IDENTITY')
@conn.exec('TRUNCATE TABLE errors RESTART IDENTITY')


# Redis

require 'redis'

@redis = Redis.new(:host => ENV['REDIS_ADDRESS'], :port => ENV['REDIS_PORT'])

@redis.flushall()
