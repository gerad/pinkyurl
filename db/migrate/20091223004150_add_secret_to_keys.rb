class AddSecretToKeys < ActiveRecord::Migration
  def self.up
    add_column :keys, :secret, :string
    Key.find_each do |k|
      k.update_attribute :secret, k.send(:random, 20)
    end
  end

  def self.down
    remove_column :keys, :secret
  end
end
