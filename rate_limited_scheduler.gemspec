Gem::Specification.new do |s|
  s.name        = 'rate_limited_scheduler'
  s.version     = '0.0.3'
  s.date        = '2013-01-11'
  s.summary     = 'A Redis-based rate-limited scheduler for requests to APIs with sensitive and time-critical access restrictions'
  s.description = "This rate-limited scheduler is made for requests to APIs with sensitive, time-critical access restrictions which means that even limits with short time intervals such as 5 requests per second can be hold in a multi-threading environment. It implements Redis-based execution handles."
  s.authors     = ['Robert Strobl']
  s.email       = 'mail@rstrobl.com'
  s.files       = ['lib/rate_limited_scheduler.rb']
  s.homepage    = 'http://github.com/rstrobl/rate_limited_scheduler'
end
