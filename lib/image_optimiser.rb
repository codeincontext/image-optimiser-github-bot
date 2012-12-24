class ImageOptimiser
  class << self
    attr_accessor :config
  end

  IGNORED_FOLDERS = %W( node_modules )
  IGNORED_FOLDERS_REGEX = Regexp.new(IGNORED_FOLDERS.join("|"))
  UNITS = %W(B KB MB).freeze

  def optimise_repository(path, force_pull_request=false)
    repo = Repository.new(path)
    repo.delete_files #in case of previous failure
    
    repo.fork
    optimisation_results = repo.optimise
    
    significant_improvement = optimisation_results[:percentage_of_assets] > 10 && optimisation_results[:saved] > 25_000
    if significant_improvement or force_pull_request
      repo.push
      repo.pull_request optimisation_results
    else
      puts "Only a #{("%0.2f" % optimisation_results[:percentage_of_assets])}% reduction (#{optimisation_results[:saved]} bytes). Haven't pushed"
    end
    
    repo.delete_files
  end
end