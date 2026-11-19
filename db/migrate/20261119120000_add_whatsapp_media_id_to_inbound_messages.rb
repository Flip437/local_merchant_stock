class AddWhatsappMediaIdToInboundMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :inbound_messages, :whatsapp_media_id, :string
  end
end
