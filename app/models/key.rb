class Key < ActiveRecord::Base
  def to_param; value end
  def self.from_param id; first :conditions => {:value => id} end

  def after_initialize
    if new_record?
      self.value ||= random(10)
      self.secret ||= random(20)
    end
  end

  private
    def random n = 10
      Base32.encode SecureRandom.random_bytes(n)
    end
end
