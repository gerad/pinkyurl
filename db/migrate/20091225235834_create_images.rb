class CreateImages < ActiveRecord::Migration
  def self.up
    create_table :images do |t|
      t.text :url
      t.string :digest

      t.timestamps
    end

    add_index :images, :digest
  end

  def self.down
    drop_table :images
  end
end
