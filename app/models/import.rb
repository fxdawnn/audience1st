class Import < ActiveRecord::Base
  require 'csv'


  @@import_types = {
    'Customer/mailing list' => 'CustomerImport',
    'Brown Paper Tickets sales list (all dates for 1 production)' => 'BrownPaperTicketsImport'
    }
  cattr_accessor :import_types
  def humanize_type
    @@import_types.index(self.type)
  end

  has_attachment(:storage => :file_system,
    :path_prefix => File.join(RAILS_ROOT, 'tmp', Option.value(:venue_shortname) || 'default'),
    :max_size => 10.megabytes)

  validates_as_attachment
  validate :valid_type?

  def valid_type?
    allowed_types = Import.import_types.values
    unless allowed_types.include?(self.type)
      errors.add_to_base "I don't understand what you're trying to import (possibilities are #{allowed_types.join(',')})"
    end
  end

  attr_accessor :messages, :pretend

  def initialize(*args)
    @messages = []
    @pretend = false            # if true, don't mutate database
    super
  end
  
  def csv_rows
    begin
      CSV::Reader.create(IO.read(self.public_filename))
    rescue Exception => e
      msg = "Getting attachment data for #{self.filename}: #{e.message}"
      errors.add_to_base(msg)
      logger.error msg
      []
    end
  end

  def preview
    raise "Must override this abstract method"
  end

end
