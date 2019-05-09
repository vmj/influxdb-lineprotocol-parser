require 'rake/clean'
require 'rake/testtask'
require 'rdoc/task'

RDoc::Task.new do |t|
  t.rdoc_files.include("lib/**/*.rb")
end

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc 'Run tests'
task default: :test
