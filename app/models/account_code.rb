class AccountCode < ActiveRecord::Base

  default_scope :order => 'code'

  has_many :donations
  has_many :vouchertypes

  validates_length_of :name, :maximum => 30, :allow_nil => true
  validates_uniqueness_of :name, :allow_nil => true
  validates_uniqueness_of :code
  validate :name_or_code_given

  attr_accessible :name, :code, :description

  def name_or_code_given
    !name.blank? || !code.blank?
  end

  def self.default_account_code_id
    self.default_account_code.id
  end
  
  def self.default_account_code
    AccountCode.first
  end

  class CannotDelete < RuntimeError ;  end
  
  # convenience accessors

  def name_or_code ;    name.blank? ? code : name        ; end
  def name_with_code ;  sprintf("%-6.6s #{name}", code)  ; end
  
  # cannot delete the last account code or the one associated as any
  # of the defaults

  before_destroy :can_be_deleted?

  def can_be_deleted?
    errors.add_to_base('at least one account code must exist') and return false if AccountCode.count < 2
    Option.columns_hash.keys.select { |name| name =~ /account_code/ }.each do |option|
      errors.add(:base, "it's the #{option.humanize.downcase}") and return false if
        code == Option.send(option)
    end
  end

end
