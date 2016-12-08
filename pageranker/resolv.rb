# Resolve URLS
class Resolv
  @redis = nil

  def initialize
    require 'redis'

    @redis = Redis.new(host: ENV['REDIS_ADDRESS'], port: ENV['REDIS_PORT'])
  end

  def add(url, doc_id)
    @redis.set("urls_#{url}", doc_id)
  end

  def doc_id(url)
    @redis.get("urls_#{url}")
  end
end
