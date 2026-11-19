# Processes one debounced batch of WhatsApp messages for a merchant:
# notify → download media / transcribe → LLM → create products → confirm.
class InboundBatchProcessor
  PROCESSING_TEXT = "⏳ Traitement de vos derniers articles…".freeze
  NOTHING_FOUND_TEXT = "🤔 Nous n'avons trouvé aucun article dans vos derniers messages. " \
                       "Envoyez une photo avec une description et le prix.".freeze
  FAILURE_TEXT = "❌ Désolé, nous n'avons pas pu traiter vos derniers articles. " \
                 "Réessayez dans quelques minutes ou ajoutez-les depuis votre espace commerçant.".freeze

  def initialize(merchant, messages, whatsapp: nil, transcriber: nil, extractor: nil)
    @merchant = merchant
    @messages = messages.sort_by { |m| [ m.created_at, m.id ] }
    @whatsapp = whatsapp
    @transcriber = transcriber
    @extractor = extractor
  end

  def call
    notify(PROCESSING_TEXT)

    items = build_items
    drafts = extractor.call(items: items, categories: Category.order(:name).pluck(:name))

    if drafts.empty?
      mark_processed
      notify(NOTHING_FOUND_TEXT)
      return []
    end

    products = create_products(drafts, items)
    notify(confirmation_text(products))
    products
  rescue StandardError => e
    Rails.error.report(e, context: { merchant_id: @merchant.id, inbound_message_ids: @messages.map(&:id) })
    InboundMessage.where(id: @messages.map(&:id)).update_all(processing_status: :error, error_message: e.message.truncate(500), updated_at: Time.current)
    notify(FAILURE_TEXT)
    []
  end

  private

  def whatsapp = @whatsapp ||= Whatsapp::Client.new
  def transcriber = @transcriber ||= AudioTranscriber.new
  def extractor = @extractor ||= ProductExtractor.new

  def reply_to = @messages.last.sender_number

  def build_items
    photo_index = 0
    @messages.map do |message|
      fetch_media(message) if message.whatsapp_media_id.present? && !message.media.attached?

      case message.message_type.to_sym
      when :image
        photo_index += 1
        ProductExtractor::Item.new(kind: :image, text: message.raw_content, data: message.media.download,
                                   content_type: message.media.content_type, index: photo_index)
      when :audio
        transcribe(message)
        ProductExtractor::Item.new(kind: :audio, text: message.transcribed_content, data: nil, content_type: nil, index: nil)
      else
        ProductExtractor::Item.new(kind: :text, text: message.raw_content, data: nil, content_type: nil, index: nil)
      end
    end
  end

  def fetch_media(message)
    media = whatsapp.download_media(message.whatsapp_media_id)
    message.media.attach(io: media.io, filename: media.filename, content_type: media.content_type)
  end

  def transcribe(message)
    return if message.transcribed_content.present?

    text = message.media.open do |file|
      transcriber.call(io: file, filename: message.media.filename.to_s, content_type: message.media.content_type)
    end
    message.update!(transcribed_content: text)
  end

  def create_products(drafts, items)
    images_by_index = items.select { |i| i.kind == :image }.index_by(&:index)
    image_messages = @messages.select(&:image?)
    categories = Category.all.index_by(&:name)

    ActiveRecord::Base.transaction do
      products = drafts.map do |draft|
        product = @merchant.products.create!(
          title: draft.title,
          description: draft.description,
          meta_description: draft.meta_description.to_s.truncate(160),
          price: draft.price&.positive? ? draft.price : nil,
          stock: [ draft.stock || 1, 0 ].max,
          category: categories[draft.category] || Category.default,
          status: :published
        )

        # Single product and no explicit mapping: it gets all the photos of the batch.
        indexes = draft.image_indexes.select { |i| images_by_index.key?(i) }
        indexes = images_by_index.keys if indexes.empty? && drafts.one?
        indexes.uniq.each do |i|
          message = image_messages[i - 1]
          product.images.attach(message.media.blob)
          message.update!(product: product)
        end
        product
      end

      @messages.reject(&:product_id).each { |m| m.update!(product: products.first) }
      mark_processed
      products
    end
  end

  def mark_processed
    InboundMessage.where(id: @messages.map(&:id)).update_all(processing_status: :processed, error_message: nil, updated_at: Time.current)
  end

  def confirmation_text(products)
    lines = products.map { |p| "• #{p.title}#{" — #{format_price(p.price)}" if p.price}" }
    header = products.one? ? "✅ 1 article publié :" : "✅ #{products.size} articles publiés :"
    [ header, *lines, "", "Vous pouvez les modifier depuis votre espace commerçant." ].join("\n")
  end

  def format_price(price)
    format("%.2f €", price).tr(".", ",")
  end

  # A failed WhatsApp reply must not break processing (or hide the original error).
  def notify(text)
    whatsapp.send_text(to: reply_to, body: text)
  rescue StandardError => e
    Rails.error.report(e, context: { merchant_id: @merchant.id })
  end
end
