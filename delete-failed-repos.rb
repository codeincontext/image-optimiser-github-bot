require 'httparty'
require 'redis'

REDIS = Redis.new

class Repo
  include HTTParty
  base_uri 'api.github.com:443'
  format :json
  basic_auth 'imageoptimiser', 'silicon1'
  headers 'Accept' => 'application/vnd.github.beta+json'

  
  attr_accessor :name
  
  def initialize(name)
    self.name = name
  end
  
  def has_pull_request?
    open_requests = self.class.get("/repos/#{name}/pulls?per_page=100").parsed_response
    raise if open_requests.count == 100
    closed_requests = self.class.get("/repos/#{name}/pulls?per_page=100&state=closed").parsed_response
    raise if closed_requests.count == 100
    
    all_requests = open_requests + closed_requests
    all_requests.any? {|r| r['user']['login'] == 'imageoptimiser'}
  end
  
  def delete_fork
    our_name = name.sub(/^.*\//, 'imageoptimiser/')
    response = self.class.delete "/repos/#{our_name}"
    puts response.code
    puts "/repos/#{our_name}"
    raise unless response.code == '204'
  end
  
  def remove_from_redis
    REDIS.del self.name
  end

end

repo_names = REDIS.keys("imageoptimiser:success:*").map { |k| k.sub('imageoptimiser:success:','') };
repos = repo_names.map { |r| Repo.new(r) }

repos.each do |repo|
  
    begin
  puts repo.name
  if repo.has_pull_request?
    puts '.     kept '+repo.name
  else
      puts 'I wanna remove '+repo.name
      repo.delete_fork
      repo.remove_from_redis

  end
  rescue => e
    puts e.inspect
  end
end