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
    results = repo.optimise
    
    significant_improvement = results[:percentage_of_assets] > 10 && results[:saved] > 75_000
    if significant_improvement or force_pull_request
      repo.push
      repo.pull_request results
    else
      if results[:optimisable_images] == 0
        puts "No optimisable images. Haven't pushed"
      else
        puts "Only a #{("%0.2f" % results[:percentage_of_assets])}% reduction (#{results[:saved]} bytes). Haven't pushed"
      end
    end
    
    repo.delete_files
  end
end