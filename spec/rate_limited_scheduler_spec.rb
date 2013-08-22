require 'rspec/mocks'
require './lib/rate_limited_scheduler.rb'

describe RateLimitedScheduler do
  before(:each) do
    @threads = []
  end
  
  after(:each) do
    @threads.each { |t| t.kill }
  end
  
  def run_threads(n_threads, ratelimiter, &block)
    n_threads.times do |i|
      @threads << Thread.new {
    	  ratelimiter.within_constraints do
    		  yield(i)
    	  end
      }
    end
  end
  
  it "should throw an exception when the connection to the redis server failed" do
    expect { 
      RateLimitedScheduler.new(:test, {:threshold => 1, :interval => 1}, {:host => 'unknown_host'})
    }.to raise_error
  end
  
  it "should have a minimum overall execution time of n threads that finish their execution during the given interval" do
    threshold = 2
    interval = 0.5
    n_executors = 5

    ratelimiter = RateLimitedScheduler.new(:test, {:threshold => threshold, :interval => interval})
    
    start_time = Time.now.to_f
    run_threads(n_executors, ratelimiter) {}

    # wait for all threads to finish execution
    @threads.each { |t| t.join }
    
    execution_time = Time.now.to_f - start_time
    min_execution_time = interval * (n_executors - 1) / threshold
            
    execution_time.should be >= min_execution_time
  end    
    
  it "should ensure that an execution that expires the given interval will delay future executions in order to hold the constraints" do
    ratelimiter = RateLimitedScheduler.new(:test, {:threshold => 2, :interval => 0.2})
    
    start_time = Time.now.to_f
    run_threads(5, ratelimiter) { |i| sleep (i+1)*0.1 }
    
    # wait for all threads to finish execution
    @threads.each { |t| t.join }
    
    execution_time = Time.now.to_f - start_time

    # Best-case scheduler after concurrency run for next execution handle:
    #
    # (*0.2s) 0 1 2 3 4 5 
    # Slot 1: A--BB--DDDD <-- 1.1s
    # Slot 2: CCC--EEEEE
    min_execution_time = 1.1    
    execution_time.should be >= min_execution_time
  end
    
  it "should not allow more executions at the same time rather than defined in the given threshold" do
    ratelimiter = RateLimitedScheduler.new(:test, {:threshold => 2, :interval => 1})
    threads = []
    
    run_threads(3, ratelimiter) { sleep 1 }
    
    # wait till all threads are started
    sleep 0.1
    
    ratelimiter.count_free_execution_handles.should eq(0)
    ratelimiter.count_active_executions.should eq(2)
  end
  
  it "should avoid starvation" do
    ratelimiter = RateLimitedScheduler.new(:test, {:threshold => 5, :interval => 0.1})
    test_object = double('test object')
    test_object.should_receive(:test).exactly(20).times
    
    run_threads(20, ratelimiter) { test_object.test }
    
    # wait for all threads to finish execution
    @threads.each { |t| t.join }
  end
  
  it "can be nested into other rate-limiters" do
    ratelimiter1 = RateLimitedScheduler.new(:test1, {:threshold => 2, :interval => 0.25})
    ratelimiter2 = RateLimitedScheduler.new(:test2, {:threshold => 1, :interval => 0.1})

    start_time = Time.now.to_f

    run_threads(6, ratelimiter1) do
      ratelimiter2.within_constraints {}
    end
  
    @threads.each { |t| t.join }
    execution_time = Time.now.to_f - start_time   
    
    execution_time.should be >= 0.6
  end
  
  it "should release handles when an exception is thrown" do
    ratelimiter = RateLimitedScheduler.new(:test, {:threshold => 1, :interval => 0.1})

    expect {
  	  ratelimiter.within_constraints do
  		  raise RuntimeError
  	  end
    }.to raise_error

    ratelimiter.count_free_execution_handles.should be(1)    
  end
  
  it "should return the last statement of the execution block" do
    ratelimiter = RateLimitedScheduler.new(:test, {:threshold => 1, :interval => 1})    
    ret = ratelimiter.within_constraints { 'foobar' }
    ret.should eq('foobar')
  end
end