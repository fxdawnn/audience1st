# -*- coding: utf-8 -*-
require 'spec_helper'

describe Customer do
  fixtures :customers
  it 'gets ID from route' do
    Customer.id_from_route("/customers/3334").should == "3334"
  end
  describe "labels" do
    before(:each) do
      @c = create(:customer)
      @l1 = Label.create!(:name => "L1")
      @l2 = Label.create!(:name => "L2")
    end
    it "should update label ID's" do
      labels = [@l2.id]
      @c.set_labels(labels)
      @c.labels.should include(@l2)
      @c.labels.should_not include(@l1)
    end
    it "should remove labels it previously had" do
      @c.labels = [@l1]
      @c.set_labels([@l2.id])
      @c.labels.should_not include(@l1)
      @c.labels.should include(@l2)
    end
    it "should remove ALL labels if nothing checked" do
      @c.labels = [@l1,@l2]
      @c.set_labels(nil)
      @c.labels.should_not include(@l1)
      @c.labels.should_not include(@l2)
    end
    it "should not have a label after label is deleted" do
      @c.labels = [@l1, @l2] ;  @c.save!
      @l2.destroy 
      @c.reload
      @c.labels.should_not include(@l2)
    end
    describe "when merging" do
      before(:each) do
        @c2 = create(:customer)
      end
      it "should keep union of labels when merging automatically" do
        @c2.labels = [@l1] ; @c2.save!
        @c.labels =  [@l2] ; @c.save!
        @c.merge_automatically!(@c2).should be_true
        @c.reload
        @c.labels.should include(@l1)
        @c.labels.should include(@l2)
      end
      it "should not barf if dupes already have overlapping label" do
        @c2.labels = [@l1] ; @c2.save!
        @c.labels  = [@l1] ; @c.save!
        @c2.merge_automatically!(@c).should be_true
        @c2.reload
        @c2.labels.should include(@l1)
      end
      it "should move the labels to the customer surviving a merge" do
        @c2.update_labels!([@l1.id])
        @c2.labels.should include(@l1)
        @c.merge_automatically!(@c2).should be_true
        @c.reload
        @c.labels.should include(@l1)
      end
    end
  end
      
  describe "special" do
    %w[walkup_customer generic_customer anonymous_customer boxoffice_daemon].each do |c|
      it "#{c.humanize} cannot be destroyed" do
        cust = Customer.send(c)
        lambda { cust.destroy }.should raise_error
      end
    end
  end
  describe "address validations" do
    context "with no mailing address" do
      before(:each) do
        @customer = Customer.create!(:first_name => "John", :last_name => "Doe",
          :password => 'xxxx', :password_confirmation => 'xxxx',
          :email => 'john@doe2.com')
      end
      it "should be valid" do
        @customer.should be_valid
      end
      it "should not be able to do credit card purchases" do
        @customer.should_not be_valid_as_purchaser
      end
      it "should not be a valid gift recipient" do
        @customer.should_not be_valid_as_gift_recipient
      end
    end
    context "with nonblank address" do
      before(:each) do
        @customer = create(:customer)
      end
      it "should be valid" do
        @customer.should be_valid
      end
      it "should be invalid if some address fields not filled in" do
        @customer.city = ''
        @customer.should_not be_valid
      end
    end
    describe "eligible as gift recipient" do
      before(:each) do
        @customer = Customer.new(:first_name => "John", :last_name => "Doe",
          :day_phone => "555-1212",
          :eve_phone => "666-2323")
        @customer.stub!(:invalid_mailing_address?).and_return(false)
        @customer.stub!(:valid_email_address?).and_return(true)
      end
      it "should be valid with valid attributes" do
        @customer.should be_valid_as_gift_recipient
      end
      it "should be valid even if only one phone number" do
        @customer.day_phone = nil
        @customer.should be_valid_as_gift_recipient
      end
      it "should have both first and last name" do
        @customer.first_name = nil
        @customer.should_not be_valid_as_gift_recipient
      end
      it "should have both first and last name, take 2" do
        @customer.last_name = nil
        @customer.should_not be_valid_as_gift_recipient
      end
      it "should have a valid mailing address" do
        @customer.stub!(:invalid_mailing_address?).and_return(true)
        @customer.should_not be_valid_as_gift_recipient
      end
      it "should have email if no day phone or eve phone" do
        @customer.eve_phone = nil
        @customer.day_phone =  nil
        @customer.should be_valid_as_gift_recipient
      end
      it "should have day phone if no email or eve phone" do
        @customer.stub!(:valid_email_address?).and_return(false)
        @customer.eve_phone = nil
        @customer.should be_valid_as_gift_recipient
      end
      it "should have eve phone if no email or day phone" do
        @customer.stub!(:valid_email_address?).and_return(false)
        @customer.day_phone = nil
        @customer.should be_valid_as_gift_recipient
      end
      it "should not be missing both phone numbers AND email" do
        @customer.day_phone = @customer.eve_phone = ''
        @customer.stub!(:valid_email_address?).and_return(false)
        @customer.should_not be_valid_as_gift_recipient
      end
    end
  end
  
  describe "find unique" do
    def names_match(a,b)
      our_first,our_last = a.split(/ +/)
      given_first,given_last = b.split(/ +/)
      Customer.new(:first_name => our_first, :last_name => our_last).name_matches(given_first,given_last)
    end
    context "when email matches" do
      before(:each) do
        @attrs = {:first_name => 'Bob', :last_name => 'Jones',
          :email => 'bobjones@mail.com',
          :street => '1234 Fake St',
          :city => 'New York', :state => 'NY', :zip => '99999'
        }
        @old = create(:customer,@attrs)
        @cust = Customer.new(@attrs)
      end
      context "and last name matches" do
        it "should match without an address" do
          [:street,:city,:state,:zip].each { |e| @attrs.delete(e) }
          Customer.find_unique(@cust).should == @old
        end
        it "should match even if addresses differ" do
          @cust.street = '999 New St'
          Customer.find_unique(@cust).should == @old
        end
        it "should match even if first names differ" do
          @cust.first_name = 'Bill'
          Customer.find_unique(@cust).should == @old
        end
      end
      context "but last name differs" do
        it "should not match if first name also differs" do
          @cust.first_name = 'Bill' ; @cust.last_name = 'Smith'
          Customer.find_unique(@cust).should be_nil
        end
      end
    end
    context "when email cannot break ties", :shared => true do
      before(:each) do
        @attrs = {:first_name => 'Bob', :last_name => 'Smith',
          :street => '99 Fake Blvd', :city => 'New York',
          :state => 'NY', :zip => '99999',
        :created_by_admin => true}
        @old = create(:customer, @attrs.merge(:email => @old_email))
        @new = Customer.new(@attrs.merge(:email => @new_email))
      end
      it "should match if first, last and address all match" do
        Customer.find_unique(@new).should == @old
      end
      [:first_name, :last_name, :street].each do |attr|
        it "should not match if #{attr} is blank in database" do
          @old.send("#{attr}=", nil)
          if @old.valid?
            @old.save
            Customer.find_unique(@new).should be_nil
          else
            true
          end
        end
        it "should not match if #{attr} is different in database" do
          @old.update_attribute(attr, @old.send(attr) << "XXX")
          Customer.find_unique(@new).should be_nil
        end
      end
    end
    context "when email isn't in our database" do
      before(:each) do
        @old_email = "nonexistent@here.com"
        @new_email = 'different@here.com'
      end
      it_should_behave_like "when email cannot break ties"
    end
    context "when email is not given" do
      before(:each) do
        @old_email = 'old_email@here.com'
        @new_email = nil
      end
      it_should_behave_like "when email cannot break ties"
    end
    context "when we have only a name" do
      # one could argue that if all we have is a name, even if it matches
      # uniquely, it could  be a very common name.  But if all we have
      # is a name and no other info on either side, it doesn't matter much.
      it "should match if first & last name match uniquely and exactly" do
        @old = create(:customer, :first_name => 'Joe', :last_name => 'Jones')
        Customer.find_unique(Customer.new(:first_name => 'Joe', :last_name => 'Jones')).should  == @old
      end
      it "should not match if first & last match exactly but not uniquely" do
        2.times { create(:customer, :first_name => 'Joe', :last_name => 'Jones') }
        Customer.find_unique(Customer.new(:first_name => 'Joe', :last_name => 'Jones')).should be_nil
      end
    end
  end

  it 'resets password' do
    customers(:quentin).update_attributes!(:password => 'new password', :password_confirmation => 'new password').should_not be_false
    Customer.authenticate(customers(:quentin).email, 'new password').should == customers(:quentin)
  end

  it 'does not rehash password' do
    customers(:quentin).update_attributes(:email => 'quentin2@email.com').should_not be_false
    Customer.authenticate('quentin2@email.com', 'monkey').should == customers(:quentin)
  end

  #
  # Authentication
  #

  it 'authenticates user' do
    Customer.authenticate(customers(:quentin).email, 'monkey').should == customers(:quentin)
    Customer.authenticate(customers(:quentin).email, 'monkey').errors.should be_empty
  end

  context "invalid login" do
    it "should display a password-incorrect message for bad password" do
      Customer.authenticate(customers(:quentin).email, 'invalid_password').errors.on(:login_failed).
        should match(/password incorrect/i)
    end
    it "should display an unknown-username message for bad username" do
      Customer.authenticate('asdkfljhadf@email.com', 'pass').errors.on(:login_failed).
        should match(/can't find that email/i)
    end
  end

  if (!defined?(REST_AUTH_SITE_KEY) || REST_AUTH_SITE_KEY.blank?)
    # old-school passwords
    it "authenticates a user against a hard-coded old-style password" do
      Customer.authenticate(customers(:old_password_holder).email, 'test').should == customers(:old_password_holder)
    end
  else
    it "doesn't authenticate a user against a hard-coded old-style password" do
      Customer.authenticate(customers(:old_password_holder).email, 'test').should be_nil
    end

    # New installs should bump this up and set REST_AUTH_DIGEST_STRETCHES to give a 10ms encrypt time or so
    desired_encryption_expensiveness_ms = 0.1
    it "takes longer than #{desired_encryption_expensiveness_ms}ms to encrypt a password" do
      test_reps = 100
      start_time = Time.now; test_reps.times{ Customer.authenticate('quentin', 'monkey'+rand.to_s) }; end_time   = Time.now
      auth_time_ms = 1000 * (end_time - start_time)/test_reps
      auth_time_ms.should > desired_encryption_expensiveness_ms
    end
  end

  #
  # Authentication
  #

  it 'sets remember token' do
    customers(:quentin).remember_me
    customers(:quentin).remember_token.should_not be_nil
    customers(:quentin).remember_token_expires_at.should_not be_nil
  end

  it 'unsets remember token' do
    customers(:quentin).remember_me
    customers(:quentin).remember_token.should_not be_nil
    customers(:quentin).forget_me
    customers(:quentin).remember_token.should be_nil
  end

  it 'remembers me for one week' do
    before = 1.week.from_now.utc
    customers(:quentin).remember_me_for 1.week
    after = 1.week.from_now.utc
    customers(:quentin).remember_token.should_not be_nil
    customers(:quentin).remember_token_expires_at.should_not be_nil
    customers(:quentin).remember_token_expires_at.between?(before, after).should be_true
  end

  it 'remembers me until one week' do
    time = 1.week.from_now.utc
    customers(:quentin).remember_me_until time
    customers(:quentin).remember_token.should_not be_nil
    customers(:quentin).remember_token_expires_at.should_not be_nil
    customers(:quentin).remember_token_expires_at.should == time
  end

  it 'remembers me default two weeks' do
    before = 2.weeks.from_now.utc
    customers(:quentin).remember_me
    after = 2.weeks.from_now.utc
    customers(:quentin).remember_token.should_not be_nil
    customers(:quentin).remember_token_expires_at.should_not be_nil
    customers(:quentin).remember_token_expires_at.between?(before, after).should be_true
  end

  protected
  def create_user(options = {})
    record = Customer.new({ :email => 'quire@example.com', :password => 'quire69', :password_confirmation => 'quire69' }.merge(options))
    record.save
    record
  end

end
