require 'rspec/mocks'
require './lib/rate_limiter.rb'

describe RateLimiter do
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
  
  it "should have a minimum overall execution time of n threads that finish their execution during the given interval" do
    threshold = 2
    interval = 0.5
    n_executors = 5

    ratelimiter = RateLimiter.new(:test, {:threshold => threshold, :interval => interval})
    
    start_time = Time.now.to_f
    run_threads(n_executors, ratelimiter) {}

    # wait for all threads to finish execution
    @threads.each { |t| t.join }
    
    execution_time = Time.now.to_f - start_time
    min_execution_time = interval * (n_executors - 1) / threshold
            
    execution_time.should be >= min_execution_time
  end    
    
  it "should ensure that an execution that expires the given interval will delay future executions in order to hold the constraints" do
    ratelimiter = RateLimiter.new(:test, {:threshold => 2, :interval => 0.2})
    
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
    ratelimiter = RateLimiter.new(:test, {:threshold => 2, :interval => 1})
    threads = []
    
    run_threads(3, ratelimiter) { sleep 1 }
    
    # wait till all threads are started
    sleep 0.1
    
    ratelimiter.count_free_execution_handles.should eq(0)
    ratelimiter.count_active_executions.should eq(2)
  end
  
  it "should avoid starvation" do
    ratelimiter = RateLimiter.new(:test, {:threshold => 5, :interval => 0.1})
    test_object = double('test object')
    test_object.should_receive(:test).exactly(20).times
    
    run_threads(20, ratelimiter) { test_object.test }
    
    # wait for all threads to finish execution
    @threads.each { |t| t.join }
  end
end