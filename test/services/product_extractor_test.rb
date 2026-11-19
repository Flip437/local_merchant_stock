require "test_helper"

class ProductExtractorTest < ActiveSupport::TestCase
  # Records the request and returns a canned chat completion.
  class FakeOpenAI
    attr_reader :request

    def initialize(content) = @content = content
    def chat = self
    def completions = self

    def create(**params)
      @request = params
      message = Struct.new(:content).new(@content)
      Struct.new(:choices).new([ Struct.new(:message).new(message) ])
    end
  end

  test "sends texts, transcriptions and photos in order, with a strict schema restricted to categories" do
    client = FakeOpenAI.new({ products: [] }.to_json)
    items = [
      ProductExtractor::Item.new(kind: :image, text: "18 €", data: "jpeg", content_type: "image/jpeg", index: 1),
      ProductExtractor::Item.new(kind: :audio, text: "Chablis 2022", data: nil, content_type: nil, index: nil),
      ProductExtractor::Item.new(kind: :text, text: "6 en stock", data: nil, content_type: nil, index: nil)
    ]

    ProductExtractor.new(client: client, model: "test-model").call(items: items, categories: [ "Autre", "Boissons" ])

    request = client.request
    assert_equal "test-model", request[:model]
    parts = request[:messages].last[:content]
    assert_equal "Catégories disponibles : Autre, Boissons", parts[0][:text]
    assert_equal "Photo n°1 — légende : 18 €", parts[1][:text]
    assert_equal "data:image/jpeg;base64,#{Base64.strict_encode64('jpeg')}", parts[2][:image_url][:url]
    assert_equal "Message vocal (transcription) : Chablis 2022", parts[3][:text]
    assert_equal "Message texte : 6 en stock", parts[4][:text]

    schema = request[:response_format][:json_schema]
    assert schema[:strict]
    assert_equal [ "Autre", "Boissons" ], schema[:schema][:properties][:products][:items][:properties][:category][:enum]
  end

  test "parses the products returned by the model" do
    content = { products: [ { title: "Chablis 2022", description: "Vin blanc.", meta_description: "Chablis", price: 18.5,
                              stock: nil, category: "Boissons", image_indexes: [ 1 ] } ] }.to_json

    drafts = ProductExtractor.new(client: FakeOpenAI.new(content), model: "m").call(items: [], categories: [ "Boissons" ])

    assert_equal 1, drafts.size
    assert_equal "Chablis 2022", drafts.first.title
    assert_nil drafts.first.stock
    assert_equal [ 1 ], drafts.first.image_indexes
  end
end
