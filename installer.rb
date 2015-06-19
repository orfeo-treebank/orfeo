#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# This is an installer for the Orfeo system. Start it in a directory
# where you want files to be stored. If installation stops for some
# reason, you can re-run the script again after fixing the issue (in
# the same directory).

require 'fileutils'
require 'open3'
require 'yaml'

# Add some simple colour codes to the string class to avoid
# a dependency on another gem such as 'colorize'.
class String
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red
    colorize(31)
  end
  def green
    colorize(32)
  end
  def yellow
    colorize(33)
  end
  def bg_blue
    colorize(44)
  end
  def grey
    colorize(37)
  end
  def light_blue
    colorize('1;34')
  end
end


# Execute a shell command. Show it and the resulting status to the
# user. Return full output of command as array of lines.
def command(cmd, story = nil)
  if story
    puts
    puts "  #{story}:"
  end
  print_command cmd

  ok = false
  output = []
  Open3.popen2e(cmd) do |stdin, stdout_err, wait_thr|
    while line = stdout_err.gets
      output << line
    end
    ok = wait_thr.value.success?
  end

  print_status ok
  cutoff_lines = 4
  if output.size < cutoff_lines
    output.each{ |x| puts "    #{x}" }
  else
    output[0..cutoff_lines].each{ |x| puts "    #{x}" }
    puts "    ...#{output.size - cutoff_lines} lines omitted...".grey
  end
  puts unless output.empty?
  abort unless ok
  return output
end

def print_command(cmd)
  print "  #{cmd}".yellow
  cutoff_chars = 40
  if cmd.length < cutoff_chars
    padding = ' ' * (cutoff_chars - cmd.length)
  else
    padding = ' '
  end
  print padding
end

def print_status(status)
  result = status ? "OK".light_blue : "FAILED".red
  puts "[#{result}]"
end

# Cross-platform way of finding an executable in the $PATH.
#   which('ruby') #=> /usr/bin/ruby
# Published by mislav on stackoverflow.
def which(cmd)
  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    exts.each { |ext|
      exe = File.join(path, "#{cmd}#{ext}")
      return exe if File.executable?(exe) && !File.directory?(exe)
    }
  end
  return nil
end

# If dir doesn't exist, get from the given git repository by
# cloning. If it does, only apply updates from git.  After the method,
# the current directory will be 'dir'. Returns true if something has
# been updated.
def git_get(url, dir)
  if File.directory? dir
    FileUtils.cd dir
    out = command "git pull", "Update the existing git files in #{dir}"
    if (!out.empty?) && out[0] =~ /Already up-to-date/
      return false
    end
  else
    command "git clone #{url} #{dir}", "Download files from #{url} to directory #{dir}"
    FileUtils.cd dir
  end
  true
end

def explain(heading)
  puts "--- #{heading} ---".bg_blue
  puts
  yield if block_given?
  puts '(press enter to continue)'.green
  input = gets
  abort if input.start_with? 'q'
end

class Task
  attr :title

  def initialize(title, explanation, proc)
    @proc = proc
    @title = title
    @explanation = explanation
    @done = false
  end

  def run
    explain(@title) { puts @explanation }
    if @proc.call
      @done = true
    end
  end

  def done?
    @done
  end
end

def show_progress(tasks)
  puts "Tasks:"
  tasks.each_with_index do |task, i|
    check = task.done? ? '✔' : '☐'
    puts "#{check} #{i+1}. #{task.title}"
  end
  puts
end


# --- These are the actual task definitions ---
tasks = []

# This 'lam' is only here because otherwise the indentation looks odd.
lam = lambda do
  print_command 'Check Ruby version'
  min_version = '1.9.3-p0'
  if RUBY_VERSION < min_version
    print_status false
    puts
    explain("Ruby #{min_version} is required.") do
      puts "Your ruby version is #{RUBY_VERSION}."
      puts "The installer will continue, but problems are to be expected."
    end
    return false
  end
  print_status true
  true
end
tasks << Task.new('Check Ruby version',
                  'This is just a simple version check.',
                  lam)

lam = lambda do
  # Sometimes the gem and the package name differ. Here, the key is
  # the package name and the value is the gem name.
  req_gems = { 'rsolr' => 'rsolr', 'zip' => 'rubyzip',
    'bundler' => 'bundler', 'rake' => 'rake' }
  req_gems.each do |req_package, req_gem|
    print_command req_gem
    begin
      require req_package
      found = true
    rescue LoadError
      found = false
    end
    print_status found
    unless found
      puts
      puts "  No worries. Trying to install #{req_gem}..."
      puts
      puts "  If the following command fails, it's probably because you cannot"
      puts "  install gems with your user credentials. If that happens, run"
      puts "  the command again with sudo and then restart the installer."
      command "gem install #{req_gem}", "Install missing gem '#{req_gem}'"
    end
  end
  true
end
tasks << Task.new('Check Ruby gems',
                  'This stage will check the required gems are installed.',
                  lam)

lam = lambda do
  req_binaries = { 'git' => 'Git',
    'javac' => 'Java Development Kit',
    'mvn' => 'Apache Maven' }
  puts "  Check for required binaries:"
  req_binaries.each do |bin, desc|
    print_command bin
    found = which(bin) != nil
    print_status found
    abort "Command #{bin} not found. Install #{desc} and try again." unless found
  end
end
tasks << Task.new('Check installed binaries',
                  'This stage will check all the required binaries are installed.',
                  lam)

lam = lambda do
  upd = git_get 'https://github.com/orfeo-treebank/ANNIS.git', 'ANNIS'
  if upd
    command "mvn install", "Build ANNIS from sources"
  else
    puts "Skipping Maven since nothing has been updated"
  end
  FileUtils.cd '..'

  annis_service_tar = Dir.glob 'ANNIS/annis-service/target/*.tar.gz'
  abort "Confused trying to find annis-service tarball" if annis_service_tar.size != 1
  annis_service_tar = annis_service_tar[0]
  annis_service_dir = File.basename(annis_service_tar).chomp('-distribution.tar.gz')

  if File.directory? annis_service_dir
    puts "Directory #{annis_service_dir} exists. It will be left untouched."
    puts "Therefore unpacking the new annis-service and starting it are skipped."
  else
    command "tar xfz #{annis_service_tar}", 'Unpack annis-service installation package'
    FileUtils.cd annis_service_dir
    ENV['ANNIS_HOME'] = Dir.pwd
    command 'bin/annis-service-no-security.sh start', 'Start annis-service'
    FileUtils.cd '..'
    settings_file = 'settings.sh'
    unless File.exist? settings_file
      File.open(settings_file, 'w') do |file|
        file.puts "export ANNIS_HOME=#{ENV['ANNIS_HOME']}"
        file.puts "export PATH=$PATH:$ANNIS_HOME/bin"
      end
      puts "Run 'source #{settings_file}' before using ANNIS service and admin scripts."
      puts "Alternatively, copy its contents into ~/.profile."
    end
  end
  true
end
tasks << Task.new('Install ANNIS', 'Now we will try to install ANNIS.', lam)

lam = lambda do
  upd = git_get 'https://github.com/orfeo-treebank/orfeo-metadata.git', 'orfeo-metadata'
  if upd
    command "bundle install", 'Ensure dependencies are installed'
    command "rake install", "Ensure the metadata module is installed"
  else
    puts "Skipping rake since nothing has been updated"
  end
  FileUtils.cd '..'

  git_get 'https://github.com/orfeo-treebank/orfeo-importer', 'orfeo-importer'
  puts "You can now set some default values. These are useful but not mandatory at this stage."
  puts "If unsure, leave the parameter empty."
  args = {}
  print "Enter base URL of ANNIS: "
  input = gets.chomp
  args[:annis_url] = input unless input.empty?
  print "Enter base URL where the sample pages are hosted: "
  input = gets.chomp
  args[:samples_url] = input unless input.empty?
  # TODO: Use something like readline to allow user to edit this.
  # For now, just put the default value in for Solr.
  args[:solr] = 'http://localhost:8983/solr/blacklight-core'
  unless args.empty?
    File.open('settings.yaml', 'w') {|f| f.write args.to_yaml }
  end
  FileUtils.cd '..'
  true
end
tasks << Task.new('Install importer',
                  "We will try to install the Orfeo importer and its dependencies.",
                  lam)


lam = lambda do
  upd = git_get 'https://github.com/orfeo-treebank/orfeo-search', 'orfeo-search'
  if upd
    command "bundle install", 'Ensure dependencies are installed'
    command "rake db:migrate jetty:stop jetty:clean orfeo:update jetty:start", "Update the search app and restart Jetty"
  else
    puts "Skipping rake since nothing has been updated"
  end

  FileUtils.cd '..'
  true
end
tasks << Task.new('Install search app',
                  "We will try to install the Orfeo text search app and its dependencies.",
                  lam)


explain('Welcome to the Orfeo installer') do
  show_progress tasks
  puts "This script will attempt to install parts of the Orfeo search portal on your system."
  puts "Files will be downloaded into the current directory (#{Dir.pwd})."
  puts "Any time you are prompted to press enter, you can instead type 'quit' or just 'q' to terminate the script."
  puts "Note that some steps may take several minutes, so do not lose patience too quickly."
  puts "NOTE: this script is not yet complete."
end


tasks.each do |task|
  task.run
  show_progress tasks
end

puts "All done!"
