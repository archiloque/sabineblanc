class CreateItems < ActiveRecord::Migration
  def self.up
    create_table :items do |t|
      t.string :url, :null => false
      t.string :title, :null => false
      t.string :tags
      t.datetime :publication_date, :null => false
      t.string :guid, :null => false
      t.string :image
      t.timestamps
    end

    add_index :items, :guid, :unique => true
    add_index :items, :publication_date
  end

  def self.down
    drop_table :items
  end
end
