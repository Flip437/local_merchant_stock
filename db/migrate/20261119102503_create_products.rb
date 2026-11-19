class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.references :merchant, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :meta_description
      t.decimal :price, precision: 10, scale: 2
      t.integer :stock, null: false, default: 1
      t.integer :status, null: false, default: 0 # published / archived
      t.string :slug, null: false
      t.integer :views_count, null: false, default: 0

      t.timestamps
    end

    add_index :products, [ :merchant_id, :slug ], unique: true
    add_index :products, :status
  end
end
