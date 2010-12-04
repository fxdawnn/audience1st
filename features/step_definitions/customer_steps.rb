World(FixtureAccess)
require File.expand_path(File.join(File.dirname(__FILE__), "..", "support", "paths"))

Given /^I am not logged in$/ do
  visit '/logout'
  response.should contain(/logged out/i)
end

Given /^I am logged in as (.*)?$/ do |who|
  is_admin = false
  case who
  when /administrator/i
    @customer = customers(:admin)
  when /nonsubscriber/i
    @customer = customers(:tom)
  when /subscriber/i
    @customer = customers(:tom)
    make_subscriber!(@customer)
  when /box ?office manager/i
    @customer = customers(:boxoffice_manager)
    is_admin = true
  when /box ?office/i
    @customer = customers(:boxoffice_user)
    is_admin = true
  when /staff/i
    @customer = customers(:staff)
    is_admin = true
  when /customer ["'](.*)['"]/
    @customer = customers($1.to_sym)
  else
    @customer = customers(:generic_customer)
  end
  visit login_path
  fill_in 'email', :with => @customer.email
  fill_in 'password', :with => 'pass'
  click_button 'Login'
  response.should contain(Regexp.new("Welcome,.*#{@customer.first_name}"))
  response.should have_selector('div[id=customer_quick_search].adminField') if is_admin
end

Then /customer "(.*)" should have label "(.*)"/i do |cust,label|
  c = customers(cust.to_sym)
  c.labels.map { |l| l.name }.should include(label)
end
