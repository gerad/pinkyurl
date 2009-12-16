class KeysBelongToPeople < ActiveRecord::Migration
  def self.up
    change_table :keys do |t|
      t.remove :secret, :images_left
      t.belongs_to :person
    end
  end

  def self.down
    change_table :keys do |t|
      t.remove :person_id
      t.string   "secret"
      t.integer  "images_left", :default => 100
    end
  end
end
