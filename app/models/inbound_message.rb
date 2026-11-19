class InboundMessage < ApplicationRecord
  belongs_to :merchant, optional: true
  belongs_to :product, optional: true
  has_one_attached :media # downloaded WhatsApp image / audio

  enum :message_type, { text: 0, audio: 1, image: 2 }
  enum :processing_status, { pending: 0, processed: 1, error: 2 }

  validates :sender_number, :message_type, :received_at, presence: true
end
