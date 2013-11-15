require 'image_optim'
require 'find'
require 'httparty'
require 'json'
require 'fileutils'

file = '24/design/twitter-bg.jpg'
origfile = '24/design/twitter-bgorig.jpg'
FileUtils.rm file if File.exist? file
FileUtils.cp origfile, file

io = ImageOptim.new
# io = ImageOptim.new(:pngout => false)

paths = [file]
results = io.optimize_images(paths) do |src, dst|
  if dst
    saved = src.size - dst.size
    percentage = (saved.to_f/src.size.to_f)*100
    puts "#{("%0.2f" % percentage)}%"
  else
    puts 'not optimised'
  end

end