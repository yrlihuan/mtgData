#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "yaml"

require "./helper"

if $PROGRAM_NAME == __FILE__
  cfg = CONFIG
  fetch = cfg['fetch']

  pattern = fetch['pattern']
  cookie = fetch['cookie']
  num_per_page = fetch['num_per_page']

  cfg['sets'].each do |dict|
    count = dict['count']
    set = dict['name'].gsub(' ', '%20')

    file_pattern = Helper.html_file_pattern(dict)

    pages = (count + num_per_page - 1) / num_per_page
    0.upto(pages-1) do |page|
      url = eval("\"#{pattern}\"")
      file = file_pattern % page

      next if File.exist? file

      cmd = %Q[curl -b "#{cookie}" -s "#{url}" > #{file}]
      `#{cmd}`
      sleep 5
    end
  end

end
