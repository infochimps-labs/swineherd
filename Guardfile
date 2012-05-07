# -*- ruby -*-

format = :doc  # doc for more verbose, progress for less
tags   = []    # only run specs with the given tag
rspec_opts = '--format #{format} #{Array(tags).map{|tag| "--tag #{tag}"}.join(" ")}'

guard 'rspec', :version => 2, :cli => rspec_opts do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^(examples/.+)\.rb})   {|m| "spec/#{m[1]}_spec.rb" }
  watch(%r{^lib/(.+)\.rb$})       {|m| ["spec/#{m[1]}_spec.rb"] }
  watch('spec/spec_helper.rb')    {    "spec" }
  watch(/spec\/support\/(.+)\.rb/){    "spec" }
end

guard 'yard' do
  watch(%r{lib/.+\.rb})
  watch(%r{notes/.+\.(md|txt)})
end
