#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "yaml"

def usage
"""ruby 1_fetch.rb config.yml"""
end

if $PROGRAM_NAME == __FILE__
  if ARGV.length != 1
    puts usage
    exit
  end

  cfg = YAML.load File.read(ARGV[0])
  fetch = cfg['fetch']

  pattern = fetch['pattern']
  cookie = fetch['cookie']
  num_per_page = fetch['num_per_page']

  cfg['sets'].each do |dict|
    time = "%.2f" % dict['time']
    code = dict['code']
    name = dict['name']
    count = dict['count']
    set = name.sub(' ', '%20')

    file_pattern = "1/#{time.sub('.', '_')}-#{code}-#{name.downcase.sub(' ', '_')}-%02d.html"

    pages = (count + num_per_page - 1) / num_per_page
    1.upto(count/num_per_page) do |page|
      url = eval("\"#{pattern}\"")
      file = file_pattern % page

      next if File.exist? file

      cmd = %Q[curl -b "#{cookie}" -s "#{url}" > #{file}]
      `#{cmd}`
      sleep 5
    end
  end

end
