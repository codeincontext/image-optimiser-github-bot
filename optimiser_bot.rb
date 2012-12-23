require 'image_optim'
require 'find'
require 'httparty'
require 'json'

require './lib/image_optimiser.rb'
require './lib/config.rb'
require './lib/repository.rb'

io = ImageOptimiser.new
io.optimise_repository 'andrew/24pullrequests'