class ImageOptimiser
  class << self
    attr_accessor :config
  end

  IGNORED_FOLDERS = %W( node_modules )
  IGNORED_FOLDERS_REGEX = Regexp.new(IGNORED_FOLDERS.join("|"))
  UNITS = %W(B KB MB).freeze

  def optimise_repository(path)
    repo = Repository.new(path)    
    repo.fork
    optimisation_results = repo.optimise
    
    if optimisation_results[:percentage_of_assets] > 5 or optimisation_results[:saved] > 512_000
      repo.push
      repo.pull_request optimisation_results
    else
      puts "Only a #{("%0.2f" % optimisation_results[:percentage_of_assets])}% reduction (#{optimisation_results[:saved]} bytes). Haven't pushed"
    end
    
    repo.delete_files
  end
end