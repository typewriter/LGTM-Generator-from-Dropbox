require 'bundler/setup'
require 'dropbox_api'
require 'RMagick'
require 'json'
require 'optparse'
require './lib/generator.rb'
require './lib/uploader.rb'

## Settings ##

ORIGINAL_IMAGE_NAME = 'sample.jpg'.freeze
OUTPUT_IMAGE_NAME = 'output.jpg'.freeze
OUTPUT_GIF_NAME = 'output.gif'.freeze
JSON_FILE_PATH = 'settings.json'.freeze
@text = 'LGTM'
@color = 'red'
@size = nil

## Methods ##

def download_image(client:, download_image_name:)
  client.download(download_image_name) do |chunk|
    open(ORIGINAL_IMAGE_NAME, 'wb') do |file|
      file << chunk
    end
  end
end


def generate_lgtm(file:, text:, color:, size:, gif:)
  img = Magick::Image.read(file).first

  if size
    unless size =~ /\dx\d/
      puts '--size option should be like `320x480`'
      return
    end

    img.change_geometry!(size) do |cols, rows, im|
      im.resize!(cols, rows)
    end
  end

  width = img.columns
  font_size = width / @text.size

  generator = gif ? Generator::Gif : Generator::Jpg
  output_file = gif ? OUTPUT_GIF_NAME : OUTPUT_IMAGE_NAME
  generator.generate!(img: img, text: text, color: color, font_size: font_size, output_file: output_file)
end

## Read options ##

params = ARGV.getopts('', 'upload', 'gif', 'color:', 'size:')

## Execution ##

puts 'Reading Settings ...'
json_data = open(JSON_FILE_PATH) do |io|
  JSON.load(io)
end

# Setup client
client = DropboxApi::Client.new(
  json_data['access_token']
)

puts 'Reading Dropbox files ...'
file_list = client.list_folder(json_data['target_directory'], recursive: true)

# Get an image randomly in the directory
file_name = file_list.entries.sample.name
download_image_name = json_data['target_directory'] + file_name

puts 'Downloading Image ...'
download_image(client: client, download_image_name: download_image_name)

puts 'Generating LGTM Image ...'
@color = params['color'] if params['color']
@size = params['size'] if params['size']
gif = params['gif']
generate_lgtm(file: ORIGINAL_IMAGE_NAME, text: @text, color: @color, size: @size, gif: gif)

if params['upload']
  puts 'Uploading Image to Gyazo ...'
  path = params['gif'] ? OUTPUT_GIF_NAME : OUTPUT_IMAGE_NAME
  access_token = json_data['gyazo_access_token']

  @image_url = UploadToGyazo.upload(path: path, access_token: access_token, is_gif: params['gif'])
end

puts 'Finish!!'
puts @image_url unless @image_url.nil?
