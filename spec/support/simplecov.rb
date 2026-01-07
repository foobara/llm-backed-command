require "simplecov"

SimpleCov.start do
  add_filter "/spec/support/"
  add_filter "/boot/"

  enable_coverage :branch
  enable_coverage :line
  minimum_coverage line: 100, branch: 100
end
