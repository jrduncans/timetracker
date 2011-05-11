#!/usr/bin/ruby

# == Name
#
# timetracker - track time in a simple text format
#
# == Synopsis
#
# *timetracker* [options] [file]
#
# Options:
#  -h -? --help,
#  -m --message
#  -p --print
#
# == Description
# Add a timestamp to the current day in the provided file
#
# <b>-h, -?, --help</b>
#	brief help message
#
# <b>-m, --message MESSAGE</b>
#	Add a message to the current day
#
# <b>-p, --print [DATE]</b>
#	Print the row for the current day
#
# <b>-d, --dry-run</b>
#	Print what the line would have looked like, but do not modify the file
#
# <b>-q, --quitting-time [HOURS]</b>
#	Print the time you would have to stop working to meet 8 hours (or the number of provided hours)
#
# <b>-r, --repair</b>
#	Reparse all lines in the file to ensure the hours worked is correct

require 'optparse'
require 'rdoc/usage'
require 'time'
require 'enumerator'

now = Time.now
date = now.strftime('%F')
time = now.strftime('%X')

options = {}

opt_parser = OptionParser.new do |opts|
  opts.banner = "Usage:\n\ttimetracker [options] [file]"
  opts.separator ''
  opts.separator 'Options:'

  opts.on('-p', '--print [DATE]', 'print the row for the current day') {|d| options[:print] = d || date}
  opts.on('-m', '--message MESSAGE', 'add a message to the current day') {|message| options[:message] = message.empty? ? ' ' : message}
  opts.on('-d', '--dry-run', 'print what the line would have looked like, but do not modify the file') {options[:dryrun] = true}
  opts.on('-q', '--quitting-time [HOURS]', 'print the time you would have to stop working to meet 8 hours (or the number of provided hours)') {|hours| options[:quitting] = (hours || '8').to_f}
  opts.on('-r', '--repair', 'reparse all lines in the file to ensure the hours worked is correct') {options[:repair] = true}

  opts.on_tail('-h', '-?', '--help', 'brief help message') do
    ENV['RI'] = '-f ansi'
    RDoc::usage
  end
end

begin
  opt_parser.parse!
rescue
  puts $!, "", opt_parser
  exit
end

filename = ARGV[0] || abort("A timesheet storage file must be provided")

lines = File.open(filename).readlines
match = []

if options[:print]
  match = lines.grep(/^[-\d]*#{options[:print]}/)
elsif options[:quitting]
  match = lines.grep(/^#{date}/)
  row = match[0].chomp.split("\t")[2..-2]

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
    row = line.chomp.split("\t")

    row[-1] = options[:message]
    line.replace(row.join("\t"))
  end

  if match.empty?
    match << "#{date}\t 0.0\t#{options[:message]}\n"
    lines << match[0]
  end
elsif options[:repair]
  lines.each do |line|
    row = line.chomp.split("\t")

    total_time = row[2..-2].to_enum(:each_slice, 2).inject(0) do |sum, pair|
      (pair.length < 2) ? sum : sum + (Time.parse(pair[1]) - Time.parse(pair[0]))
    end

    row[1] = sprintf('%4.1f', total_time / (60.0 * 60.0))
    line.replace(row.join("\t"))
  end
else
  match = lines.grep(/^#{date}/) do |line|
    row = line.chomp.split("\t")
    row = row[0..-2] << time << row[-1]

    total_time = row[2..-2].to_enum(:each_slice, 2).inject(0) do |sum, pair|
      (pair.length < 2) ? sum : sum + (Time.parse(pair[1]) - Time.parse(pair[0]))
    end

    row[1] = sprintf('%4.1f', total_time / (60.0 * 60.0))
    line.replace(row.join("\t"))
  end

  if match.empty?
    match << "#{date}\t 0.0\t#{time}\t \n"
    lines << match[0]
  end
end

File.open(filename, 'w').puts lines unless options[:dryrun] or options[:print] or options[:quitting]
puts match
