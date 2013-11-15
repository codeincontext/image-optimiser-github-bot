class ImageOptimiser
  
  class PullRequestFailureException < RuntimeError; end
  class ForkException < RuntimeError; end
  
  class Repository
    include HTTParty
    base_uri 'api.github.com:443'
    basic_auth ImageOptimiser.config[:auth][:username], ImageOptimiser.config[:auth][:password]
    format :json
    
    def initialize(path)
      @path = path
    end

    def fork
      response = self.class.post("/repos/#{@path}/forks")
      raise ForkException, "Code: #{response.code}" unless response.code == 202

      `cd repos; git clone ssh://ghio/imageoptimiser/#{name}.git`
      
      commit_count = cmd('git count-objects').split(' ').first.to_i
      puts "commit count: #{commit_count}"
      raise ForkException if commit_count == 0
    end

    def optimise
      io = ImageOptim.new
      paths = []
      Find.find(local_path) do |path|
        paths << path if File.file?(path) && io.optimizable?(path) && path !~ IGNORED_FOLDERS_REGEX
      end
      total_asset_size = 0
      total_saved = 0
      optimisable_images = 0
      results = io.optimize_images(paths) do |src, dst|
        total_asset_size += src.size

        if dst
          optimisable_images += 1
          saved = src.size - dst.size
          total_saved += saved
          percentage = (saved.to_f/src.size.to_f)*100
          percentage = "#{("%0.2f" % percentage)}%"
          
          dst.replace(src)
          {:name => src.to_s, :percentage => percentage}
        else
          nil
        end
      end
      results.compact!

      # add files to git outside optimisation loop to avoid threading issues
      if optimisable_images > 0
        git_filepaths = results.map { |r| r[:name].sub("#{local_path}/",'') }
        puts git_filepaths
        cmd "git add #{git_filepaths.join(' ')}"
      end
      
      {
        :optimisable_images => optimisable_images,
        :saved => total_saved,
        :percentage_of_assets => (total_saved.to_f/total_asset_size.to_f)*100,
        :results => results
      }
    end

    def push
      cmd "git commit -m\"Optimised images\" --author \"imageoptimiser <skattyadz+imageoptimiser@gmail.com>\""
      cmd "git push origin master:optimised-images"
    end

    def pull_request(data)
      text = generate_pull_text(data)
      
      puts text
      params = {
        :title => "Optimise images (#{as_size(data[:saved])} reduction)",
        :body => text,
        :head => "imageoptimiser:optimised-images",
        :base => "master"
      }.to_json
      response = self.class.post("/repos/#{@path}/pulls", { :body => params} )
      
      puts response.code
      unless response.code == 201
        puts response.inspect
        raise PullRequestFailureException 
      end
    end
    
    def delete_files
      `rm -rf #{local_path}`
    end
    
  private
    def cmd(command)
      `cd #{local_path} && #{command}`
    end
    
    def name
      @path.split('/').last
    end
    
    def local_path
      "repos/#{name}"
    end

    def as_size(number)
      if number.to_i < 1024
        exponent = 0

      else
        max_exp  = UNITS.size - 1

        exponent = ( Math.log( number ) / Math.log( 1024 ) ).to_i # convert to base
        exponent = max_exp if exponent > max_exp # we need this to avoid overflow for the highest unit

        number  /= 1024 ** exponent
      end

      "#{number} #{UNITS[ exponent ]}"
    end
    
    def generate_pull_text(data)
      text = <<-eos
Hi, #{@path.split('/').first}.

I've taken the liberty of putting #{name}'s image assets though a range of optimisation tools. Image optimisation allows us to reduce the footprint of images - meaning faster load times at no cost to image quality. It does this by finding the best (lossless) compression parameters, stripping embedded comments, and removing unnecessary colour profiles. [See more](http://port3000.co.uk/imageoptimiser-a-github-bot-to-proactively-op).

I found #{data[:optimisable_images]} optimisable images, making a #{as_size(data[:saved])} reduction in size. That's about #{("%0.2f" % data[:percentage_of_assets])}% of your total image assets.

Merry Christmas.

      eos

      text << "<table><tr><th>Name</th><th>Reduction</th></tr>"
      text = data[:results].inject(text) do |t, r|
        t + "<tr><td>#{r[:name].split('/').last}</td><td>#{r[:percentage]}</td></tr>"
      end
      text << "</tr></table>

Tools used: advpng, gifsicle, jpegoptim, jpegrescan, jpegtran, optipng, pngcrush, pngout. This is an automated bot maintained by [@skattyadz](https://twitter.com/skattyadz)"
      
      text
    end
  end
end