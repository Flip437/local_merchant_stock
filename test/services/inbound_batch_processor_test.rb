require "test_helper"

class InboundBatchProcessorTest < ActiveSupport::TestCase
  setup do
    @merchant = create_merchant
    @boissons = Category.find_or_create_by!(name: "Boissons")
    @whatsapp = FakeWhatsapp.new
  end

  test "photo + voice note: notifies, transcribes, creates a product with the photo and confirms" do
    photo = msg(:image, media: "img-1")
    voice = msg(:audio, media: "aud-1")
    extractor = FakeExtractor.new([ draft ])

    products = process([ photo, voice ], extractor:, transcriber: FakeTranscriber.new("Chablis 2022, 18 euros, j'en ai 6"))

    assert_equal "⏳ Traitement de vos derniers articles…", @whatsapp.sent.first[:body]
    assert_equal "+33612345678", @whatsapp.sent.first[:to]

    assert_equal [ :image, :audio ], extractor.items.map(&:kind)
    assert_equal "fake-jpeg-1", extractor.items.first.data
    assert_equal 1, extractor.items.first.index
    assert_equal "Chablis 2022, 18 euros, j'en ai 6", extractor.items.last.text
    assert_includes extractor.categories, "Boissons"

    product = products.sole
    assert product.published?
    assert_equal @boissons, product.category
    assert_equal 18.5, product.price
    assert_equal 6, product.stock
    assert_equal 1, product.images.count, "single product gets all batch photos"

    assert [ photo, voice ].all? { |m| m.reload.processed? && m.product == product }
    assert_equal "Chablis 2022, 18 euros, j'en ai 6", voice.transcribed_content

    confirmation = @whatsapp.sent.last[:body]
    assert_match "✅ 1 article publié", confirmation
    assert_match "Chablis 2022 — 18,50 €", confirmation
  end

  test "several products in one batch get their own photos" do
    photo1 = msg(:image, media: "img-1")
    photo2 = msg(:image, media: "img-2")
    text = msg(:text, content: "Photo 1 : Chablis 18 €, photo 2 : Sancerre 22 €")
    extractor = FakeExtractor.new([ draft(image_indexes: [ 1 ]), draft(title: "Sancerre 2023", price: 22, image_indexes: [ 2 ]) ])

    products = process([ photo1, photo2, text ], extractor:)

    assert_equal [ "Chablis 2022", "Sancerre 2023" ], products.map(&:title)
    assert_equal [ "fake-jpeg-1" ], products.first.images.map(&:download)
    assert_equal [ "fake-jpeg-2" ], products.last.images.map(&:download)
    assert_equal products.last, photo2.reload.product
    assert_equal products.first, text.reload.product
    assert_match "✅ 2 articles publiés", @whatsapp.sent.last[:body]
  end

  test "unknown category falls back to Autre, missing stock defaults to 1, bad values are cleaned" do
    product = process([ msg(:text, content: "Un truc") ],
                      extractor: FakeExtractor.new([ draft(category: "Inexistante", stock: nil, price: -3) ])).sole

    assert_equal Category::DEFAULT_NAME, product.category.name
    assert_equal 1, product.stock
    assert_nil product.price
  end

  test "no product found: messages processed, merchant told" do
    message = msg(:text, content: "Bonjour !")
    assert_empty process([ message ], extractor: FakeExtractor.new([]))

    assert message.reload.processed?
    assert_match "aucun article", @whatsapp.sent.last[:body]
    assert_equal 0, Product.count
  end

  test "LLM failure: messages flagged as error, merchant told, no product" do
    message = msg(:text, content: "Chablis 18 €")
    extractor = FakeExtractor.new { raise "OpenAI timeout" }

    assert_empty process([ message ], extractor:)

    assert message.reload.error?
    assert_equal "OpenAI timeout", message.error_message
    assert_match "pas pu traiter", @whatsapp.sent.last[:body]
    assert_equal 0, Product.count
  end

  private

  def process(messages, extractor:, transcriber: FakeTranscriber.new(""))
    InboundBatchProcessor.new(@merchant, messages, whatsapp: @whatsapp, transcriber: transcriber, extractor: extractor).call
  end

  def msg(type, media: nil, content: nil)
    @sequence = (@sequence || 0) + 1
    @merchant.inbound_messages.create!(sender_number: "+33612345678", message_type: type, whatsapp_media_id: media,
                                       raw_content: content, received_at: Time.current,
                                       created_at: @sequence.seconds.from_now, processing_status: :processing)
  end
end
