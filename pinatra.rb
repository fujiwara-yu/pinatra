require 'sinatra'
require './picasa_client'
require 'json'
require 'pp'

def find_album_by_name(client, album_name)
  client.album.list.entries.find {|a| a.title == album_name}
end

def pinatra_cache_file_name(album)
  "pinatra.#{album.id}.#{album.etag}.cache"
end

picasa_client = Pinatra::PicasaClient.new.client

get "/hello" do
  "Suzuki Shinra!!"
end

get "/:album/photos" do
  contents = []
  callback = params['callback']
  album = find_album_by_name(picasa_client, params[:album])
  return "Not found" unless album

  cache_file = pinatra_cache_file_name(album)
  if File.exists?(cache_file)
    json = File.open(cache_file).read
  else
    photos = picasa_client.album.show(album.id, {thumbsize: "128c"}).photos
    photos.each do |p|
      thumb = p.media.thumbnails.first
      photo = {
        src: p.content.src,
        title: p.title,
        id: p.id,
        thumb: {
          url: thumb.url,
          width: 128,
          height: 128
        }
      }
      contents << photo
    end
    json = contents.to_json
  end

  if callback
    content_type :js
    content = "#{callback}(#{json});"
  else
    content_type :json
    content = json
  end

  File.open(cache_file, "w") do |file|
    file.print json
  end

  return content
end

# Upload contents of files as image.
# Accept POST method with multipart/form-data.
# Set parameter name to /file\d+/ (e.g. file1, file2 ...).
# Example: curl -F file1=@./image1.jpg -F file2=@./image2.jpg \
#          'localhost:4567/nomnichi/photo/new'
# Default photo name is uploaded file name.
# If specify, set parameter such as following.
# /nomnichi/photo/new?title=photoname
# FIXME?: if several files are uploaded and title parameter is set,
#        all uploaded photos titles are same.
post "/:album/photo/new" do
  album = find_album_by_name(picasa_client, params[:album])
  return "Not found" unless album

  contents = []
  files_key = params.keys.select {|key| key =~ /file\d+/}
  files_key.each do |key|
    param = params[key]
    # FIXME: decision by filename extension.
    photo = picasa_client.photo.create(album.id, binary: param[:tempfile].read, content_type: "image/jpeg", title: (params['title'] || param[:filename]))
    thumb = photo.media.thumbnails.first
    hash = {
      src: photo.content.src,
      title: photo.title,
      id: photo.id,
      thumb: {
        url: thumb.url,
        width: 128,
        height: 128
      }
    }
    contents << hash
  end

  json = contents.to_json
  content_type :json

  return json
end
