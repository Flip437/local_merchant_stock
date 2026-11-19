module Webhooks
  # Meta WhatsApp Cloud API webhook.
  # Inherits from ActionController::API: no CSRF, no browser version check.
  class WhatsappController < ActionController::API
    # GET — subscription verification performed by Meta when configuring the webhook.
    def verify
      if params["hub.mode"] == "subscribe" &&
         ActiveSupport::SecurityUtils.secure_compare(params["hub.verify_token"].to_s, ENV.fetch("WHATSAPP_VERIFY_TOKEN"))
        render plain: params["hub.challenge"]
      else
        head :forbidden
      end
    end

    # POST — incoming messages. Must answer fast: heavy work happens in InboundBatchJob.
    def receive
      return head :unauthorized unless valid_signature?

      Whatsapp::InboundRecorder.call(JSON.parse(request.raw_post))
      head :ok
    rescue JSON::ParserError
      head :bad_request
    end

    private

    # Meta signs the raw body with the app secret: X-Hub-Signature-256: sha256=<hex>
    def valid_signature?
      signature = request.headers["X-Hub-Signature-256"].to_s
      expected = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch("WHATSAPP_APP_SECRET"), request.raw_post)
      ActiveSupport::SecurityUtils.secure_compare(signature, expected)
    end
  end
end
