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

now = Time.now
date = now.strftime('%Y-%m-%d')
time = now.strftime('%X')

options = {:count => 5}

opt_parser = OptionParser.new do |opts|
  opts.banner = "Usage:\n\ttimetracker [options] [file]"
  opts.separator ''
  opts.separator 'Options:'

  opts.on('-p', '--print [DATE]', 'print the row for the current day') {|d| options[:print] = d || date}
  opts.on('-m', '--message MESSAGE', 'add a message to the current day') {|message| options[:message] = message.empty? ? '' : message.gsub(/\s+/, ' ').chomp}
  opts.on('-d', '--dry-run', 'print what the line would have looked like, but do not modify the file') {options[:dryrun] = true}
  opts.on('-q', '--quitting-time [HOURS]', 'print the time you would have to stop working to meet 8 hours (or the number of provided hours)') {|hours| options[:quitting] = (hours || '8').to_f}
  opts.on('-r', '--repair', 'reparse all lines in the file to ensure the hours worked is correct') {options[:repair] = true}
  opts.on('-l', '--list', 'list the most recent entries (limited by -c)') {options[:list] = true}
  opts.on('-c', '--count [COUNT]', 'restrict list-based functionality to the most recent [COUNT]') {|count| options[:count] = count.nil? ? 5 : count.to_i}

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

def should_print(opts)
  opts[:dryrun] or opts[:print] or opts[:quitting] or opts[:list]
end

def parse_row(line)
  row = line.chomp.split(/\s{2,}|\t/)
  if row[-1] =~ /^\d{2}:\d{2}:\d{2}$/
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

  match = (Time.parse(row[-1]) + (options[:quitting] * 3600.0 - total_time)).strftime('%X')
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
  lines.each do |line|
    row = parse_row(line)

    total_time = row[2..-2].to_enum(:each_slice, 2).inject(0) do |sum, pair|
      (pair.length < 2) ? sum : sum + (Time.parse(pair[1]) - Time.parse(pair[0]))
    end

    row[1] = sprintf('%4.1f', total_time / (60.0 * 60.0))
    line.replace(to_line(row))
  end
elsif options[:list]
  match = lines[-options[:count]..lines.length].join
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

File.open(filename, 'w').puts lines if should_print(options)
puts match
