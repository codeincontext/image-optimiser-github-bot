class ImageOptimiser
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
      raise "nope" unless response.code == 202

      `cd repos; git clone ssh://ghio/imageoptimiser/#{name}.git`
    end

    def optimise
      io = ImageOptim.new
      paths = []
      Find.find(local_path) do |path|
        paths << path if File.file?(path) && io.optimizable?(path) && path !~ IGNORED_FOLDERS_REGEX
      end
      total_asset_size = 0
      size_before_optimisation = 0
      size_after_optimisation = 0
      optimisable_images = 0

      results = io.optimize_images(paths) do |src, dst|
        total_asset_size += src.size
        nil
        # puts src
        if dst
          size_before_optimisation += src.size
          size_after_optimisation += dst.size
          optimisable_images += 1
          
          saved = src.size - dst.size
          percentage = (saved.to_f/src.size.to_f)*100
          percentage = "#{("%0.2f" % percentage)}%"
          # dst.replace(src)
          file_to_add = src.to_s.sub("#{local_path}/",'')
          cmd "git add #{file_to_add}"
          
          {:name => src.to_s, :percentage => percentage}
        end
      end
      
      saved = size_before_optimisation - size_after_optimisation

      {
        :optimisable_images => optimisable_images,
        :saved => saved,
        :average_saving => (saved.to_f/size_before_optimisation.to_f)*100,
        :percentage_of_assets => (saved.to_f/total_asset_size.to_f)*100,
        :results => results
      }
    end

    def push
      puts cmd "git commit -m\"Optimised images\" --author \"imageoptimiser <imageoptimiser@skatty.me>\""
      puts cmd "git push -u"
    end

    def pull_request(data)
      text = generate_pull_text(data)
      
      puts text
      params = {
        :title => "Optimise images",
        :body => text,
        :head => "imageoptimiser:master",
        :base => "master"
      }.to_json
      response = self.class.post("/repos/#{@path}/pulls", { :body => params} )
      
      # puts response.inspect
      puts response.code
      # raise "nope" unless response.code == 201
    end
    
    def delete_files
      `rm -rf #{local_path}`
    end
    
  private
    def cmd(command)
      `cd #{local_path}; #{command}`
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
Hi, maintainer.

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