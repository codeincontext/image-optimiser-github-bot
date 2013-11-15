require 'httparty'
require 'json'
require 'redis'

class User
  include HTTParty
  base_uri 'api.github.com:443'
  format :json
  basic_auth 'imageoptimiser', 'silicon1'
  headers 'Accept' => 'application/vnd.github.beta+json'
  
  attr_accessor :name
  
  def initialize(name)
    self.name = name
  end
  
  def repos
    response = self.class.get("/users/#{name}/repos?per_page=100").parsed_response
    # response.map { |r| r['full_name'] }
  end

  def following
    response = self.class.get("/users/#{name}/following?per_page=100").parsed_response
    response.map { |u| User.new(u['login']) }
  end

  def starred_repos
    self.class.get("/users/#{name}/starred?per_page=100").parsed_response
  end
end

me = User.new 'skattyadz'
# repos = me.following.map{ |f| f.repos }.flatten
# repos = me.following.map{ |f| f.starred_repos }.flatten

me.following.each do |user|
  repos = user.starred_repos
  repos.uniq!
  repos.select! { |r| r['watchers_count'] > 20 }


  puts repos
  REDIS = Redis.new
  repos.each do |repo|
    REDIS.rpush 'imageoptimiser:queue', repo['full_name']
  end
end

# repos = me.starred_repos
# repos.uniq!
# repos.select! { |r| r['watchers_count'] > 20 }
# 
# 
# puts repos
# REDIS = Redis.new
# repos.each do |repo|
#   REDIS.rpush 'imageoptimiser:queue', repo['full_name']
# end

# users = me.following.inject([me]) { |result, user| result + user.following }
# repos = users.inject([]) { |result, user| result + user.starred_repos }
# 
# puts repos.count
# repos.select! { |r| r['watchers_count'] > 20 }
# puts repos.count
# 
# 
# 
# repos = ["twitter/bootstrap", "joyent/node", "jquery/jquery", "h5bp/html5-boilerplate", "rails/rails", "bartaz/impress.js", "documentcloud/backbone", "mbostock/d3", "mxcl/homebrew", "octocat/Spoon-Knife", "harvesthq/chosen", "FortAwesome/Font-Awesome", "mrdoob/three.js", "blueimp/jQuery-File-Upload", "mojombo/jekyll", "visionmedia/express", "adobe/brackets", "robbyrussell/oh-my-zsh", "zurb/foundation", "textmate/textmate", "Modernizr/Modernizr", "diaspora/diaspora", "github/gitignore", "jquery/jquery-mobile", "plataformatec/devise", "cloudhead/less.js", "facebook/three20", "LearnBoost/socket.io", "necolas/normalize.css", "torvalds/linux", "documentcloud/underscore", "jashkenas/coffee-script", "jquery/jquery-ui", "meteor/meteor", "symfony/symfony", "gitlabhq/gitlabhq", "antirez/redis", "angular/angular.js", "nvie/gitflow", "defunkt/jquery-pjax", "hakimel/reveal.js", "emberjs/ember.js", "mathiasbynens/dotfiles", "addyosmani/backbone-fundamentals", "joshuaclayton/blueprint-css", "AFNetworking/AFNetworking", "mozilla/pdf.js", "django/django", "EllisLab/CodeIgniter", "addyosmani/todomvc"]
# 
# REDIS = Redis.new
# repos.each do |repo|
#   REDIS.rpush 'imageoptimiser:queue', repo
# end