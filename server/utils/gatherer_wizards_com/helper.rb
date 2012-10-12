# encoding: utf-8

require "rubygems"
require "yaml"

CONFIG = YAML.load File.read('site.yml')

class Helper
  def self.html_file_pattern(set)
    time = "%.2f" % set['time']
    code = set['code']
    name = set['name']
    count = set['count']

    file_pattern = "1/#{time.sub('.', '_')}-#{code}-#{name.downcase.sub(' ', '_')}-%02d.html"
  end
end

