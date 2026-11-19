# Sends a batch of merchant messages (texts, transcriptions, photos) to the LLM and returns
# structured product drafts. One batch can describe several products.
class ProductExtractor
  Draft = Data.define(:title, :description, :meta_description, :price, :stock, :category, :image_indexes)

  # A batch item, in the order the merchant sent them.
  # kind: :text, :audio or :image; for images, `data` is the raw bytes and `index` its photo number.
  Item = Data.define(:kind, :text, :data, :content_type, :index)

  SYSTEM_PROMPT = <<~PROMPT.freeze
    Tu aides des commerçants locaux à publier leurs produits en ligne.
    Tu reçois les messages WhatsApp d'un commerçant (textes, transcriptions de vocaux, photos numérotées),
    dans l'ordre d'envoi. Identifie chaque produit distinct décrit et renvoie une fiche par produit.

    Règles :
    - title : nom court et précis du produit, comme un client le chercherait sur Google (marque, modèle, taille, couleur si connus).
    - description : 2 à 5 phrases factuelles en français, sans inventer de caractéristiques absentes des messages ou des photos.
    - meta_description : 150 caractères maximum, pour Google.
    - price : prix unitaire en euros, null si non mentionné.
    - stock : quantité disponible, null si non mentionnée.
    - category : choisis obligatoirement dans la liste fournie ; "%<default>s" si rien ne correspond.
    - image_indexes : numéros des photos qui montrent ce produit.
    - Si les messages ne décrivent aucun produit, renvoie une liste vide.
  PROMPT

  def initialize(client: OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY")),
                 model: ENV.fetch("OPENAI_MODEL", "gpt-4o"))
    @client = client
    @model = model
  end

  # @return [Array<Draft>]
  def call(items:, categories:)
    completion = @client.chat.completions.create(
      model: @model,
      messages: [
        { role: "system", content: format(SYSTEM_PROMPT, default: Category::DEFAULT_NAME) },
        { role: "user", content: user_content(items, categories) }
      ],
      response_format: { type: :json_schema, json_schema: { name: "products", strict: true, schema: schema(categories) } }
    )

    JSON.parse(completion.choices.first.message.content).fetch("products").map do |product|
      Draft.new(**product.transform_keys(&:to_sym))
    end
  end

  private

  def user_content(items, categories)
    parts = [ { type: :text, text: "Catégories disponibles : #{categories.join(', ')}" } ]
    items.each do |item|
      case item.kind
      when :image
        parts << { type: :text, text: "Photo n°#{item.index}#{" — légende : #{item.text}" if item.text.present?}" }
        parts << { type: :image_url, image_url: { url: "data:#{item.content_type};base64,#{Base64.strict_encode64(item.data)}" } }
      when :audio
        parts << { type: :text, text: "Message vocal (transcription) : #{item.text}" }
      else
        parts << { type: :text, text: "Message texte : #{item.text}" }
      end
    end
    parts
  end

  def schema(categories)
    {
      type: "object",
      additionalProperties: false,
      required: [ "products" ],
      properties: {
        products: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            required: %w[title description meta_description price stock category image_indexes],
            properties: {
              title: { type: "string" },
              description: { type: "string" },
              meta_description: { type: "string" },
              price: { type: [ "number", "null" ] },
              stock: { type: [ "integer", "null" ] },
              category: { type: "string", enum: categories },
              image_indexes: { type: "array", items: { type: "integer" } }
            }
          }
        }
      }
    }
  end
end
