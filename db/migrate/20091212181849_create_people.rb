class CreatePeople < ActiveRecord::Migration
  def self.up
    create_table :people do |t|
      t.string :email, :null => false
      t.string :crypted_password, :null => false
      t.string :persistence_token, :null => false
      t.string :perishable_token, :null => false

      t.integer :login_count, :null => false, :default => 0
      t.datetime :current_login_at
      t.datetime :last_login_at

      t.timestamps
    end
  end

  def self.down
    drop_table :people
  end
end
