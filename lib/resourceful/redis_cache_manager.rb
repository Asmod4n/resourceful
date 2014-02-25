require 'resourceful/cache_manager'
require 'redis'
require 'time'

module Resourceful
  class RedisCacheManager < AbstractCacheManager
    def initialize
      @redis = Redis.new
    end

    def lookup(request)
      response = cache_entries_for(request)[request]
      response.authoritative = false if response
      response
    end

    def store(request, response)
      return unless response.cacheable?

      entries = cache_entries_for(request)
      entries[request] = response

      @redis.set(uri_hash(request.uri), Marshal.dump(entries), ex: expires(response.header))
    end

    def invalidate(uri)
      @redis.delete(uri_hash(uri))
    end

    private
    def expires(header)
      if header.cache_control and m_age_str = header.cache_control.find{|cc| /^max-age=/ === cc}
        m_age_str[/\d+/].to_i
      elsif header.expires
        Time.httpdate(header.expires).to_i - Time.httpdate(header.date).to_i
      else
        nil
      end
    end

    def cache_entries_for(request)
      if entries = @redis.get(uri_hash(request.uri))
        Marshal.load(entries)
      else
        Resourceful::CacheEntryCollection.new
      end
    end
  end
end
