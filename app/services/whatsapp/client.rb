module Whatsapp
  # Thin wrapper around the Meta WhatsApp Cloud API (Graph API).
  class Client
    class Error < StandardError; end

    Media = Data.define(:io, :content_type, :filename)

    GRAPH_URL = "https://graph.facebook.com".freeze

    def initialize(access_token: ENV.fetch("WHATSAPP_ACCESS_TOKEN"),
                   phone_number_id: ENV.fetch("WHATSAPP_PHONE_NUMBER_ID"),
                   api_version: ENV.fetch("WHATSAPP_API_VERSION", "v23.0"))
      @access_token = access_token
      @phone_number_id = phone_number_id
      @api_version = api_version
    end

    def send_text(to:, body:)
      request(:post, "#{@phone_number_id}/messages",
              messaging_product: "whatsapp",
              to: to.delete_prefix("+"),
              type: "text",
              text: { preview_url: false, body: body })
    end

    # Media ids stay valid ~30 days; the download URL returned by Meta expires after ~5 minutes,
    # so we resolve it right before downloading.
    def download_media(media_id)
      meta = request(:get, media_id)
      response = connection.get(meta.fetch("url"))
      raise Error, "media download failed (#{response.status})" unless response.success?

      content_type = meta["mime_type"].to_s.split(";").first.presence || "application/octet-stream"
      extension = Rack::Mime::MIME_TYPES.invert[content_type] || ".bin"
      Media.new(io: StringIO.new(response.body), content_type: content_type, filename: "#{media_id}#{extension}")
    end

    private

    def request(method, path, body = nil)
      url = "#{GRAPH_URL}/#{@api_version}/#{path}"
      response = method == :get ? connection.get(url) : connection.post(url, body.to_json, "Content-Type" => "application/json")
      payload = JSON.parse(response.body.presence || "{}")
      raise Error, "WhatsApp API #{response.status}: #{payload.dig('error', 'message') || response.body}" unless response.success?

      payload
    end

    def connection
      @connection ||= Faraday.new(headers: { "Authorization" => "Bearer #{@access_token}" }) do |f|
        f.options.timeout = 30
        f.options.open_timeout = 5
      end
    end
  end
end
