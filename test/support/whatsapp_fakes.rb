# Test doubles for external services (WhatsApp, OpenAI).
class FakeWhatsapp
  MEDIA = {
    "img-1" => [ "image/jpeg", "fake-jpeg-1" ],
    "img-2" => [ "image/jpeg", "fake-jpeg-2" ],
    "aud-1" => [ "audio/ogg", "fake-ogg" ]
  }.freeze

  attr_reader :sent

  def initialize = @sent = []

  def send_text(to:, body:) = @sent << { to: to, body: body }

  def download_media(media_id)
    content_type, bytes = MEDIA.fetch(media_id)
    Whatsapp::Client::Media.new(io: StringIO.new(bytes), content_type: content_type, filename: "#{media_id}.bin")
  end
end

class FakeTranscriber
  def initialize(text) = @text = text
  def call(io:, filename:, content_type:) = @text
end

class FakeExtractor
  attr_reader :items, :categories

  def initialize(drafts = nil, &block)
    @drafts = drafts
    @block = block
  end

  def call(items:, categories:)
    @items = items
    @categories = categories
    @block ? @block.call : @drafts
  end
end

module DraftHelper
  def draft(**attrs)
    ProductExtractor::Draft.new(**{ title: "Chablis 2022", description: "Vin blanc de Bourgogne.", meta_description: "Chablis 2022",
                                    price: 18.5, stock: 6, category: "Boissons", image_indexes: [] }.merge(attrs))
  end
end
