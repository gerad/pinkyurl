class Key < ActiveRecord::Base
  belongs_to :person

  def to_param; secret end
  def self.from_param id; find_by_secret! id end

  def after_initialize
    if new_record?
      self.value ||= random 10
      self.secret ||= random 20
    end
  end

  private
    def random n = 10
      Base32.encode SecureRandom.random_bytes(n)
    end
end
