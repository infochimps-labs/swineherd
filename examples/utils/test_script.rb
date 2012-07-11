#!/usr/bin/env ruby
require 'multi_json'
require 'configliere'

$stdout.sync = true


Settings.use :commandline
Settings.define :exitstatus, type: Integer, description: "exit status to return"
Settings.define :read_stdin, type: Symbol,  description: "if `true`, will read stdin; if `fail`, will read 7 bytes and then exit; if `false`, will not read stdin"
Settings.resolve!

info = {
  argv:     ARGV,
  settings: Settings,
  pwd:      Dir.pwd,
  # path:     ENV['PATH'],
  env:      ENV.select{|var,val| var =~ /shrd_/i },
}

case Settings.read_stdin.to_s
when 'true'      then info[:input] = $stdin.read
when '', 'false' then info[:input] = nil
when 'fail'      then info[:input] = $stdin.read(11) ; $stdin.close 
else warn "Don't understand value for read_stdin: #{Settings.read_stdin}"
end

$stderr.puts MultiJson.dump({greeting: "hello to stderr"}, pretty: true)

$stdout.puts MultiJson.dump(info.merge({greeting: "hello to stdout"},), pretty: true)

exit(Settings.exitstatus) if Settings.exitstatus
