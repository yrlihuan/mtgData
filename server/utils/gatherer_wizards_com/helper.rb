# encoding: utf-8

require "rubygems"
require "yaml"

CONFIG = YAML.load File.read('site.yml')

class String
  def startwith?(characters)
      self.match(/^#{characters}/) ? true : false
  end
end

class Helper
  def self.ensure_dir_existing(dir)
    unless File.exist? dir
      `mkdir -p #{dir}`
    end
  end

  def self.html_file_pattern(set)
    time = "%.2f" % set['time']
    code = set['code']
    name = set['name']
    count = set['count']

    file_pattern = "1/#{time.sub('.', '_')}-#{code}-#{name.downcase.gsub(' ', '_')}-%02d.html"
  end

  def self.parsed_file_pattern(set)
    html = self.html_file_pattern(set)

    file = html.sub('html', 'json')
    '2' + file[1..-1]
  end

  def self.image_file_pattern(set)
    time = "%.2f" % set['time']
    code = set['code']
    name = set['name']
    count = set['count']

    file_pattern = "3/#{time.sub('.', '_')}-#{code}-#{name.downcase.gsub(' ', '_')}-%02d/%d.jpg"
  end
end

