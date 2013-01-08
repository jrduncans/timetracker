#!/usr/bin/env ruby

# Copyright 2011 Stephen Duncan Jr
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'optparse'
require 'time'
require 'enumerator'
require 'gruff'

class Time
  def round(seconds = 60)
    Time.at((self.to_f / seconds).round * seconds)
  end

  def floor(seconds = 60)
    Time.at((self.to_f / seconds).floor * seconds)
  end

  def round_to_closest_minute
    if self.sec > 30 && (self.hour != 23 && self.min != 59)
      self.round(60)
    else
      self.floor(60)
    end
  end
end

format_date = '%Y-%m-%d %a'
format_time = '%H:%M'
expected_hours = {
  'Sun' => 0,
  'Mon' => 8,
  'Tue' => 8,
  'Wed' => 8,
  'Thu' => 8,
  'Fri' => 8,
  'Sat' => 0
}

now = Time.now
date = now.strftime(format_date)
time = now.round_to_closest_minute().strftime(format_time)

options = {}

opt_parser = OptionParser.new do |opts|
  opts.banner = "Usage:\n\ttimetracker [options] [file]"
  opts.separator ''
  opts.separator 'Options:'

  opts.on('-p', '--print [DATE]', 'print the row for the current day') {|d| options[:print] = d || date}
  opts.on('-m', '--message MESSAGE', 'add a message to the current day') {|message| options[:message] = message.empty? ? '' : message.gsub(/\s+/, ' ').chomp}
  opts.on('-d', '--dry-run', 'print what the line would have looked like, but do not modify the file') {options[:dryrun] = true}
  opts.on('-g', '--graph [REGEX]', 'graph time for current month (unless regex is provided)') {|regex| options[:graph] = (regex || now.strftime('%Y-%m'))}
  opts.on('-q', '--quitting-time [HOURS]', 'print the time you would have to stop working to meet 8 hours (or the number of provided hours)') {|hours| options[:quitting] = (hours || '8').to_f}
  opts.on('-r', '--repair', 'reparse all lines in the file to ensure the hours worked is correct') {options[:repair] = true}

  opts.on_tail('-h', '-?', '--help', 'brief help message') do
	puts opts
	exit
  end
end

begin
  opt_parser.parse!
rescue
  puts $!, "", opt_parser
  exit
end

filename = ARGV[0] || abort("A timesheet storage file must be provided")

def parse_row(line)
  row = line.chomp.split(/\s{2,}|\t/)
  if row[-1] =~ /^\d{2}:\d{2}$/
    row << ''
  end

  row
end

def to_line(row)
  row.reject {|s| s.empty?}.join(' ' * 4)
end

lines = File.readable?(filename) ? File.open(filename).readlines : []
match = []

if options[:print]
  match = lines.grep(/^[-\d]*#{options[:print]}/)
elsif options[:graph]
  filename = 'timesheet-' + options[:graph] + '.png'
  days = []
  days_actual = []
  days_expected = []
  total_actual = 0
  total_expected = 0
  index = 0
  index_labels = { }
  lines.grep(/^[-\d]*#{options[:graph]}/) do |line|
    row = parse_row(line)

    days.push(expected_hours[Time.parse(row[0]).strftime('%d')])
    days_actual.push(row[1].to_f)
    total_actual += row[1].to_f

    if (Time.parse(row[0]) < (Time.now - (24*60*60)))
        if (line.match(/sick|vacation|holiday/))
            total_expected += 0
            days_expected.push(0)
        else
            total_expected += expected_hours[Time.parse(row[0]).strftime('%a')]
            days_expected.push(expected_hours[Time.parse(row[0]).strftime('%a')])
        end
    end

    if (Time.parse(row[0]).strftime('%a') == 'Sun')
        index_labels[index] = Time.parse(row[0]).strftime('%m/%d')
    end
    index += 1
  end

  graph = Gruff::Line.new('800x400')
  graph.title = options[:graph] + "\nOvertime " + (total_actual.to_i - total_expected).to_s + " Hours"

  graph.top_margin = 10
  graph.right_margin = 10
  graph.bottom_margin = 10
  graph.left_margin = 10

  graph.legend_font_size = 12
  graph.marker_font_size = 12
  graph.title_font_size = 16

  graph.line_width = 2
  graph.dot_radius = 1
  graph.minimum_value = 0
  graph.maximum_value = 24

  graph.theme = {
    :colors => %w(#FF420E #004586),
    :marker_color => '#CCCCCC',
    :background_colors => %w(#FFFFFF #FFFFFF)
  }

  graph.data("Worked " + total_actual.to_i.to_s + " Hours", days_actual)
  graph.data("Expected " + total_expected.to_s + " Hours", days_expected)

  graph.labels = index_labels

  graph.write(filename)
  puts 'timetracker graph written to ' + filename
elsif options[:quitting]
  match = lines.grep(/^#{date}/)
  row = match[0]
  unless row
    puts 'You must have started the day to calculate quitting time.'
    exit
  end
  row = parse_row(row)[2..-2]

  if row.length % 2 == 0
    puts 'You must be currently working to calculate quitting time.'
    exit
  end

  total_time = row[0...-1].to_enum(:each_slice, 2).inject(0) do |sum, pair|
    sum + (Time.parse(pair[1]) - Time.parse(pair[0]))
  end

  match = (Time.parse(row[-1]) + (options[:quitting] * 3600.0 - total_time)).round_to_closest_minute().strftime(format_time)
elsif options[:message]
  match = lines.grep(/^#{date}/) do |line|
    row = parse_row(line)

    row[-1] = options[:message]
    line.replace(to_line(row))
  end

  if match.empty?
    match << to_line([date, '0.0', options[:message], "\n"])
    lines << match[0]
  end
elsif options[:repair]
  previous_day = ''
  repaired_lines = []
  lines.each do |line|
    row = parse_row(line)

    # repair date/time format
    row[0] = Time.parse(row[0]).strftime(format_date)
    row.map!{ |field| (field =~ /(\d:)+/) ? Time.parse(field).round_to_closest_minute().strftime(format_time) : field }

    # insert missing days
    if (previous_day != '')
      while (previous_day != row[0] && row[0] != (Time.parse(previous_day) + (25*60*60)).strftime(format_date)) do
        previous_day = (Time.parse(previous_day) + (25*60*60)).strftime(format_date)
        repaired_lines.push(previous_day + "     0.0")
        puts "inserting missing day: " + previous_day
      end
    end

    total_time = row[2..-2].to_enum(:each_slice, 2).inject(0) do |sum, pair|
      (pair.length < 2) ? sum : sum + (Time.parse(pair[1]) - Time.parse(pair[0]))
    end

    previous_day = row[0]
    row[1] = sprintf('%4.1f', total_time / (60.0 * 60.0))
    repaired_lines.push(to_line(row))
  end
  lines = repaired_lines
else
  match = lines.grep(/^#{date}/) do |line|
    row = parse_row(line)

    # check if this day was already inserted without any timestamps
    if row[2..-2].length > 0
        row = row[0..-2] << time << row[-1]
    else
        row = row[0..-2] << row[-1] << time
    end

    total_time = row[2..-2].to_enum(:each_slice, 2).inject(0) do |sum, pair|
      (pair.length < 2) ? sum : sum + (Time.parse(pair[1]) - Time.parse(pair[0]))
    end

    row[1] = sprintf('%4.1f', total_time / (60.0 * 60.0))
    line.replace(to_line(row))
  end

  if match.empty?
    match << to_line([date, ' 0.0', time, "\n"])
    lines << match[0]
  end
end

File.open(filename, 'w').puts lines unless options[:dryrun] or options[:print] or options[:quitting] or options[:graph]
puts match
