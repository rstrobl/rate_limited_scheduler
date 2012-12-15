Rate-limited Scheduler
======================

[![Build Status](https://travis-ci.org/rstrobl/rate_limited_scheduler.png)](https://travis-ci.org/rstrobl/rate_limited_scheduler)

This rate-limited scheduler is made for requests to APIs with sensitive, time-critical access restrictions which 
means that even limits with short time intervals such as 5 requests per second can be hold in a multi-threading 
environment. It implements Redis-based execution handles.

### Motivation

After investigating on other rate-limiters I figured out that most of them just start counting at the entry point of
an execution unit. If this execution unit makes API requests, the actual request time that reaches the server can be 
anywhere between the entry point and the exit point. This might lead to scheduling conflicts since requests at the end
of one timeslot get close to units from the next timeslot. In this rate-limiter I make use of the exit point
in order to ensure that the API limits are even hold for short-time intervals. The implementation uses Redis-based 
execution handles which allows to also provide full functionality in multi-threading environment.

### Outlook

This rate-limiter must not be used for API limits only of course. Another use-case would be to frequently send emails 
during a given time interval. If you have other use-cases I am curious to know about it. Please send me an email.

## Installation

	gem install rate_limited_scheduler

## Usage

```ruby
# instantiate RateLimitedScheduler with Redis bucket named :api_requests and a rate of 5 executions / 0.5 seconds
ratelimiter = RateLimitedScheduler.new(:api_requests, {:threshold => 5, :interval => 0.5})

10.times do
  ratelimiter.within_constraints do
    # make API request
  end
end
```
    
This would be a sequential run. But you can also use threads:

```ruby
10.times do
  new Thread {
    ratelimiter.within_constraints do
      # make API request
    end
  }
end
```

You can also nest rate-limiters for multiple API limits:

```ruby
# allow 2000 executions per day and 5 executions / second
day_ratelimiter = RateLimitedScheduler.new(:day_requests, {:threshold => 3000, :interval => 86400})
second_ratelimiter = RateLimitedScheduler.new(:second_requests, {:threshold => 5, :interval => 1})

5000.times do
  day_ratelimiter.within_constraints do
    second_ratelimiter.within_constraints do
      # make API request
    end
  end
end
```
