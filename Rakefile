# frozen_string_literal: true

require "rake"
require "rake/testtask"

Rake::TestTask.new do |task|
  task.libs << "lib"
  task.pattern = "spec/**/*_spec.rb"
end

task default: :test
