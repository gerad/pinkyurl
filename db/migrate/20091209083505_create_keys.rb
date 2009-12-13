class CreateKeys < ActiveRecord::Migration
  def self.up
    create_table :keys do |t|
      t.string :value, :secret
      t.integer :images_left, :default => 100

      t.timestamps
    end
    add_index :keys, :value
  end

  def self.down
    drop_table :keys
  end
end
