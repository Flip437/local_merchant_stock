module Whatsapp
  # Turns a webhook payload into InboundMessage records and (re)schedules the batch job.
  #
  # Each WhatsApp item (photo, voice note, text) arrives as a separate message. Every new message
  # from a merchant schedules InboundBatchJob 60 s later; only the job triggered by the most recent
  # message actually processes the batch (debounce), see InboundBatchJob.
  class InboundRecorder
    SUPPORTED_TYPES = %w[text image audio].freeze

    def self.call(payload) = new(payload).call

    def initialize(payload)
      @payload = payload
    end

    def call
      messages.each { |message| record(message) }
    end

    private

    def messages
      Array(@payload["entry"]).flat_map { |entry| Array(entry["changes"]) }
                              .flat_map { |change| Array(change.dig("value", "messages")) }
    end

    def record(message)
      return unless SUPPORTED_TYPES.include?(message["type"])
      return if InboundMessage.exists?(whatsapp_message_id: message["id"]) # Meta retries deliveries

      sender = "+#{message['from']}"
      merchant = PhoneNumber.find_by(number: sender)&.merchant

      inbound = InboundMessage.create!(
        merchant: merchant,
        sender_number: sender,
        whatsapp_message_id: message["id"],
        message_type: message["type"],
        raw_content: message.dig("text", "body") || message.dig("image", "caption"),
        whatsapp_media_id: message.dig(message["type"], "id"), # image / audio only
        received_at: Time.zone.at(message["timestamp"].to_i),
        processing_status: merchant ? :pending : :error,
        error_message: merchant ? nil : "Numéro inconnu"
      )

      InboundBatchJob.set(wait: InboundBatchJob::WINDOW).perform_later(inbound) if merchant
    rescue ActiveRecord::RecordNotUnique
      # Concurrent duplicate delivery of the same message: already recorded.
    end
  end
end
