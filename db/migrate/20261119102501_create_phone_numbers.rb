class CreatePhoneNumbers < ActiveRecord::Migration[8.1]
  def change
    create_table :phone_numbers do |t|
      t.references :merchant, null: false, foreign_key: true
      t.string :number, null: false # E.164, e.g. +33612345678
      t.boolean :primary, null: false, default: false

      t.timestamps
    end

    add_index :phone_numbers, :number, unique: true
    add_index :phone_numbers, :merchant_id, unique: true, where: '"primary" = true', name: "index_phone_numbers_one_primary_per_merchant"
  end
end
