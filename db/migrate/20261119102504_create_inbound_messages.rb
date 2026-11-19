class CreateInboundMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :inbound_messages do |t|
      t.references :merchant, foreign_key: true # null when the sender number is unknown
      t.references :product, foreign_key: true  # set once the product is created
      t.string :sender_number, null: false
      t.string :whatsapp_message_id               # Meta message id, for idempotency
      t.integer :message_type, null: false        # text / audio / image
      t.text :raw_content
      t.text :transcribed_content
      t.integer :processing_status, null: false, default: 0 # pending / processed / error
      t.text :error_message
      t.datetime :received_at, null: false

      t.timestamps
    end

    add_index :inbound_messages, :whatsapp_message_id, unique: true, where: "whatsapp_message_id IS NOT NULL"
    add_index :inbound_messages, [ :merchant_id, :processing_status ]
  end
end
