Gem::Specification.new do |s|
  s.name        = 'rate_limiter'
  s.version     = '0.0.1'
  s.date        = '2012-12-13'
  s.summary     = 'A Redis-based rate-limiter for sensitive, time-critical API access restrictions'
  s.description = "This rate-limiter is made for sensitive, time-critical API requests which means that even limits with short time intervals such as 5 requests per second can be hold in a multi-threading environment. It implements Redis-based execution handles."
  s.authors     = ['Robert Strobl']
  s.email       = 'mail@rstrobl.com'
  s.files       = ['lib/rate_limiter.rb']
  s.homepage    = 'http://github.com/rstrobl/rate_limiter'
end
