require 'redis'
require 'redis-namespace'

class RateLimitedScheduler
  class Configuration
    attr_accessor :default_threshold, :default_interval
  end
  
  def self.configure(&block)
    block.call(@@configuration)
  end

  @@configuration = Configuration.new
  
  self.configure do |config|
    config.default_threshold = 5
    config.default_interval = 1
  end  
  
  def initialize(bucket, constraint)
    # default: 5 executions per second
    constraint[:threshold] ||= @@configuration.default_threshold
    constraint[:interval] ||= @@configuration.default_interval
    
    @bucket = bucket
    @constraint = constraint
    @redis = Redis::Namespace.new(:ratelimiter, { :redis => Redis.new })
    
    @redis.multi do
      @redis.del(@bucket)
      @redis.lpush(@bucket, Array.new(constraint[:threshold], Time.now.to_f))
    end
  end
  
  def within_constraints(&block)      
    start_execution
    yield
    stop_execution
  end
  
  def count_active_executions
    @constraint[:threshold] - count_free_execution_handles
  end
  
  def count_free_execution_handles
    @redis.llen(@bucket)
  end
  
  private
  
  def get_execution_handle(subscriber)
    execution_handle = @redis.lpop(@bucket)
    unless execution_handle.nil?
      subscriber.unsubscribe(:new_execution_handle_available)
      return execution_handle
    end
  end
  
  def wait_for_execution_handle
    subscriber = Redis::Namespace.new(:ratelimiter, { :redis => Redis.new })
    
    subscriber.subscribe(:new_execution_handle_available) do |on|
      execution_handle = get_execution_handle(subscriber)
      return execution_handle unless execution_handle.nil?
      
      on.message do
        execution_handle = get_execution_handle(subscriber)
        return execution_handle unless execution_handle.nil?
      end
    end
  end
  
  def start_execution
    execution_handle = wait_for_execution_handle
    current_time = Time.now.to_f
            
    # got next execution handle, wait till it gets valid
    if execution_handle.to_f > current_time
      sleep(execution_handle.to_f - current_time)
    end
  end
  
  def stop_execution
    @redis.multi do
      @redis.rpush(@bucket, Time.now.to_f + @constraint[:interval])
      @redis.publish(:new_execution_handle_available, nil)
    end
  end
end
