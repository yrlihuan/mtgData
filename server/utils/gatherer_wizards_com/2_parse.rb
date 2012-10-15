#!/usr/bin/env ruby
# encoding: utf-8

require "rubygems"
require "yaml"
require "nokogiri"
require "json"

require "./helper"

# this parser takes an html file as input
# the result is an array of records (cards),
# each of which is like
#
# name: Angel of Serenity
# name_zh: 清朗天使
# cost: 4,W,W,W (任意颜色用数字，五种颜色分别是RGBUW，二选一颜色用RG, BU, UW等, 无色可选用X, 新非瑞克西亚用PR,PG,PB等)
# cost_total: 10 (X对应于0)
# color: W (R,G,B,U,W,N for non,M for multi,X for multi alternative)
# category: Creature (Creature, Instant, Sorcery, Legendary Creature, Enchantment, Artifact Creature, Planeswalker, Artifact, ...)
# subcategory: Angel (Human, ...)
# abilities: Flying, Trample, Infect, Exalted, Haste, Defender, Bloodthirst,
#            Firststrike, Vigilance, Deathtouch, Flash, Reach, Landfall,
#            Undying, Lifelink, Hexproof, Overload, Intimidate, Metalcraft,
#            Unleash, Scavenge, Doublestrike, Islandwalk, Swampwalk, Devour,
#            Plainswalk, Forestwalk, Mountainwalk, Battlecry, Regenerate, ...
# strength: 5
# defense: 6
# desc: "Flying\nWhen Angel of Serenity enters the battlefield, you may exile up to three other target creatures from the battlefield and/or creature cards from graveyards.\n  When Angel of Serenity leaves the battlefield, return the exiled cards to their owners' hands."
# set: rtr (list of set separated by ',')
# images: 204828,204832
# rarity: C/U/R/M
#

Abilities = ["Flying", "Trample", "Infect", "Exalted", "Haste", "Defender", "Bloodthirst",
             "Firststrike", "Vigilance", "Deathtouch", "Flash", "Reach", "Landfall",
             "Undying", "Lifelink", "Hexproof", "Overload", "Intimidate", "Metalcraft",
             "Unleash", "Scavenge", "Doublestrike", "Islandwalk", "Swampwalk", "Devour",
             "Plainswalk", "Forestwalk", "Mountainwalk", "Battlecry", "Regenerate"]

def rarity_image(n)
  link = n.get_attribute 'href'
  if link =~ /.*=([0-9]*)$/
    id = $1
  else
    id = nil
  end

  set_rarity = n.at_xpath('img').get_attribute 'alt'
  if set_rarity =~ /(.*)\((.*)\)/
    set = $1
    rarity = $2
  else
    set = nil
    rarity = nil
  end

  [id, set, rarity]
end

def rarity_code(r)
  if r == 'Common' or r == 'Land'
    'C'
  elsif r == 'Uncommon'
    'U'
  elsif r == 'Rare'
    'R'
  elsif r == 'Mythic Rare'
    'M'
  else
    warn "unknown rarity code #{r}"
    exit
  end
end

def mana_code(c)
  if c == 'Green'
    'G'
  elsif c == 'Black'
    'B'
  elsif c == 'White'
    'W'
  elsif c == 'Blue'
    'U'
  elsif c == 'Red'
    'R'
  else
    false
  end
end

def extract_type(node)
  card = {}
  info = node.at_xpath('td[2]/div[2]/span[@class="typeLine"]').text.strip

  # valid values for info
  #   Instant
  #   Creature  \342\200\224 Bird\r\n                                (2/1)
  type, build = info.split("\r\n")
  type.strip!
  category, subcategory = type.split('  — ')

  card['category'] = category
  card['subcategory'] = subcategory

  if build
    build.strip!
    if build =~ /\(([0-9*]*)\/([0-9*]*)\)/
      card['strength'] = $1
      card['defense'] = $2
    elsif build =~ /\(([0-9]*)\)/
      card['strength'] = 0
      card['defense'] = $1
    else
      warn "unexpected build value: #{build}"
      card['strength'] = nil
      card['defense'] = nil
    end
  else
    card['strength'] = nil
    card['defense'] = nil
  end

  card
end

def extract_title(node)
  card = {}
  title = node.at_xpath('td[2]/div[2]/span[@class="cardTitle"]/a').text
  warn "title not found" unless title =~ /(.*)\((.*)\)/

  card['name_zh'] = $1
  card['name'] = $2

  card
end

def extract_mana(node)
  card = {}

  costNode = node.at_xpath('td[2]/div[2]/span[@class="manaCost"]')
  costs = []
  color = "N"
  total = 0
  costNode.xpath('img').each do |img|
    c = img.get_attribute('alt')
    if c =~ /[0-9]+/
      costs << c
      total += c.to_i
    elsif c =~ /(.*) or (.*)/
      costs << "#{mana_code($1)}#{mana_code($2)}"
      total += 1

      if color != 'N' and color != 'X'
        color = 'M'
      else
        color = 'X'
      end
    elsif c == 'Variable Colorless'
      costs << 'X'
      total += 0
    elsif c.startwith? 'Phyrexian'
      code = mana_code(c[10..-1])
      costs << 'P' + code
      total += 1

      if color == 'N' or color == code
        color = code
      else
        color = 'M'
      end
    else
      code = mana_code(c)
      costs << code
      total += 1

      if color == 'N' or color == code
        color = code
      else
        color = 'M'
      end
    end
  end

  if costs.include? false
    warn "unknown color name #{c}"
    warn node.text
    exit
  end

  card['cost'] = costs.join ','
  card['cost_total'] = total
  card['color'] = color

  # hey, we have a chance to do a check against site data
  if node.at_xpath('td[2]/div[2]/span[@class="convertedManaCost"]').text.to_i != total
    warn "calculated cost and cost from site not match!"
    warn node.text
    exit
  end

  card
end

def extract_desc(node)
  card = {}

  descNode = node.at_xpath('td[2]/div[2]/div[@class="rulesText"]')

  texts = []
  descNode.xpath('p').each do |p|
    texts << p.text
  end

  desc = texts.join "\n"
  card["desc"] = desc

  card
end

def extract_abilities(card)
  if card['category'].include? 'Creature'
    return {'abilities' => ''}
  end

  dict = {}

  desc = card['desc'].downcase
  abilities = []

  Abilities.each do |abi|
    if desc.include? abi.downcase
      abilities << abi
    end
  end

  dict['abilities'] = abilities.join ','

  dict
end

def extract_images(node)
  card = {}

  mainImageNode = node.at_xpath('td[3]/div[2]/div/a')
  id, current_set, rarity = rarity_image(mainImageNode)

  ids = [id]

  node.xpath('td[3]/div[@class="otherSetSection"]/div[2]/a').each do |n|
    id, set, rr = rarity_image(n)

    if set == current_set
      ids << id
    end
  end

  if ids.include? nil or current_set == nil or rarity == nil
    warn 'error when extracting rarity info'
    warn node.text
  end

  card['images'] = ids.join ','
  card['rarity'] = rarity_code(rarity)

  card
end

if $PROGRAM_NAME == __FILE__
  cfg = CONFIG
  fetch = cfg['fetch']

  num_per_page = fetch['num_per_page']

  cfg['sets'].each do |dict|
    count = dict['count']
    html_pattern = Helper.html_file_pattern(dict)
    json_pattern = Helper.parsed_file_pattern(dict)

    pages = (count + num_per_page - 1) / num_per_page
    0.upto(pages-1) do |page|
      data = []
      html = html_pattern % page
      json = json_pattern % page

      next unless File.exist? html
      next if File.exist? json

      content = File.read(html)
      doc = Nokogiri::HTML(content)

      doc.xpath('//tr[@class]').each do |node|
        card = {}

        card.merge! extract_title(node)
        card.merge! extract_type(node)
        card.merge! extract_mana(node)
        card.merge! extract_desc(node)
        card.merge! extract_images(node)
        card.merge! extract_abilities(card)

        card['set'] = dict['code']

        data << card
      end

      json_content = JSON.dump(data)
      File.open(json, 'w').write(json_content)
    end
  end
end
