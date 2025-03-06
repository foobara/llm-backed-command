RSpec.configure do |config|
  cleanup = proc do
    Foobara::CachedCommand.cache.clear

    if File.exist?("tmp/cached_command")
      FileUtils.rm_r("tmp/cached_command")
    end
  end

  config.before(:suite, &cleanup)
  config.after(:each, &cleanup)
end
