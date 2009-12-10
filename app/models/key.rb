class Key < ActiveRecord::Base
  def to_param; Rack::Utils.escape value end
  def self.from_param id; first :conditions => ['BINARY value = ?', id] end

  def after_initialize
    if new_record?
      self.value ||= SecureRandom.base64 12
      self.secret ||= SecureRandom.base64 24
    end
  end
end
