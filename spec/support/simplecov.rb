require "simplecov"

SimpleCov.start do
  skip "/spec/support/"
  skip "/boot/"

  enable_coverage :branch
  enable_coverage :line
  minimum_coverage line: 100, branch: 100
end
