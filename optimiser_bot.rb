require 'image_optim'
require 'find'
require 'httparty'
require 'json'
require 'redis'

require './lib/image_optimiser.rb'
require './lib/config.rb'
require './lib/repository.rb'

REDIS = Redis.new
io = ImageOptimiser.new

while true
  queue, repo = REDIS.blpop "imageoptimiser:queue"
  next if REDIS.exists "imageoptimiser:success:#{repo}" #or REDIS.exists "imageoptimiser:fail:#{repo}"
  
  begin
    puts "processing #{repo}"
    io.optimise_repository repo
    puts "success: #{repo}"
    REDIS.set "imageoptimiser:success:#{repo}", Time.now.utc
  rescue
    puts "fail: #{repo}"
    puts $!, $@
    REDIS.set "imageoptimiser:fail:#{repo}", Time.now.utc
  end
end