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
    row = row[0..-2] << time << row[-1]

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

File.open(filename, 'w').puts lines unless options[:dryrun] or options[:print] or options[:quitting]
puts match
