#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "yaml"
require "nokogiri"
require "json"

require "./helper"

if $PROGRAM_NAME == __FILE__
  cfg = CONFIG
  fetch = cfg['fetch']

  url_pattern = fetch['image_pattern']
  num_per_page = fetch['num_per_page']

  cfg['sets'].each do |dict|
    count = dict['count']
    json_pattern = Helper.parsed_file_pattern(dict)
    image_pattern = Helper.image_file_pattern(dict)

    pages = (count + num_per_page - 1) / num_per_page
    0.upto(pages-1) do |page|
      json = json_pattern % page
      dir = File.dirname(image_pattern % [page, 0])
      Helper.ensure_dir_existing(dir)

      data = JSON.load(File.read(json))
      data.each do |card|
        card['images'].split(',').each do |id|
          jpg_file = image_pattern % [page, id]

          next if File.exist? jpg_file

          url = eval("\"#{url_pattern}\"")
          cmd = %Q[wget -q -O #{jpg_file} "#{url}"]

          `#{cmd}`
          sleep 3

          if File.size(jpg_file) == 73739
            warn "placeholder image downloaded! id: #{id}"
            exit
          elsif File.size(jpg_file) < 10000
            warn "file size < 10000! id: #{id}"
            exit
          end
        end
      end
    end
  end
end

