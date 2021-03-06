# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV["RAILS_ENV"] ||= 'test'
require File.dirname(__FILE__) + "/../config/environment" unless defined?(RAILS_ROOT)
require 'spec/autorun'
require 'spec/rails'
require 'timecop'
require 'spec/support/redirect_to_path.rb'

TEST_FILES_DIR = File.join(RAILS_ROOT, 'spec', 'import_test_files') unless defined?(TEST_FILES_DIR)

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

include AuthenticatedTestHelper

Spec::Runner.configure do |config|
  config.use_transactional_fixtures = false
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end
  config.before(:each) do 
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.start
    # seed the DB with seed data - necessary for Options and config info
    load File.join(Rails.root, 'db', 'seeds.rb')
    # Freeze time
    Timecop.travel(Date.parse 'Mar 1, 2012')
  end
  config.after(:each) do
    DatabaseCleaner.clean
    Timecop.return
  end

  config.use_instantiated_fixtures  = false
  config.fixture_path = RAILS_ROOT + '/spec/fixtures/'
  config.global_fixtures = :options
  config.include AuthenticatedTestHelper
  config.include CustomMatchers
  config.include FactoryGirl::Syntax::Methods
  config.include ApplicationHelper
  config.include ActionView::Helpers

  # == Fixtures
  #
  # You can declare fixtures for each example_group like this:
  #   describe "...." do
  #     fixtures :table_a, :table_b
  #
  # Alternatively, if you prefer to declare them only once, you can
  # do so right here. Just uncomment the next line and replace the fixture
  # names with your fixtures.
  #
  # config.global_fixtures = :table_a, :table_b
  #
  # If you declare global fixtures, be aware that they will be declared
  # for all of your examples, even those that don't use them.
  #
  # You can also declare which fixtures to use (for example fixtures for test/fixtures):
  #
  # config.fixture_path = RAILS_ROOT + '/spec/fixtures/'
  #
  # == Mock Framework
  #
  # RSpec uses it's own mocking framework by default. If you prefer to
  # use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  #
  # == Notes
  #
  # For more information take a look at Spec::Runner::Configuration and Spec::Runner
end

ActiveRecord::Base.colorize_logging = false

