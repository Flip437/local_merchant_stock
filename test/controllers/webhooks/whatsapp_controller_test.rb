require "test_helper"

class Webhooks::WhatsappControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { @merchant = create_merchant(phone: "+33612345678") }

  test "verify echoes the challenge with the right token" do
    get "/webhooks/whatsapp", params: { "hub.mode" => "subscribe", "hub.verify_token" => "test-verify-token", "hub.challenge" => "42" }
    assert_response :ok
    assert_equal "42", response.body
  end

  test "verify rejects a wrong token" do
    get "/webhooks/whatsapp", params: { "hub.mode" => "subscribe", "hub.verify_token" => "nope", "hub.challenge" => "42" }
    assert_response :forbidden
  end

  test "rejects a payload with an invalid signature" do
    post_webhook payload(text_message), signature: "sha256=deadbeef"
    assert_response :unauthorized
    assert_equal 0, InboundMessage.count
  end

  test "records messages from a known merchant and schedules the batch 60 s later" do
    freeze_time do
      assert_enqueued_jobs 2, only: InboundBatchJob do
        post_webhook payload(image_message, audio_message)
      end
      assert_response :ok

      image, audio = InboundMessage.order(:id).to_a
      assert_equal [ @merchant, @merchant ], [ image.merchant, audio.merchant ]
      assert image.image? && image.pending?
      assert_equal "img-1", image.whatsapp_media_id
      assert_equal "Prix 18 €", image.raw_content
      assert audio.audio?
      assert_equal "aud-1", audio.whatsapp_media_id

      assert_enqueued_with job: InboundBatchJob, args: [ audio ], at: 60.seconds.from_now
    end
  end

  test "ignores duplicate deliveries of the same message" do
    post_webhook payload(text_message)
    post_webhook payload(text_message)
    assert_equal 1, InboundMessage.count
  end

  test "logs messages from unknown numbers as errors without scheduling a job" do
    assert_no_enqueued_jobs do
      post_webhook payload(text_message(from: "33700000000"))
    end
    message = InboundMessage.last
    assert message.error?
    assert_nil message.merchant
    assert_equal "+33700000000", message.sender_number
  end

  test "ignores status updates and unsupported message types" do
    body = { entry: [ { changes: [ { value: { statuses: [ { id: "wamid.s", status: "delivered" } ],
                                              messages: [ { from: "33612345678", id: "wamid.v", timestamp: "1700000000", type: "video", video: { id: "v1" } } ] } } ] } ] }
    post_webhook body
    assert_response :ok
    assert_equal 0, InboundMessage.count
  end

  private

  def post_webhook(body, signature: nil)
    raw = body.to_json
    signature ||= "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", "test-app-secret", raw)
    post "/webhooks/whatsapp", params: raw, headers: { "Content-Type" => "application/json", "X-Hub-Signature-256" => signature }
  end

  def payload(*messages)
    { object: "whatsapp_business_account", entry: [ { id: "1", changes: [ { field: "messages", value: { messaging_product: "whatsapp", messages: messages } } ] } ] }
  end

  def text_message(from: "33612345678")
    { from: from, id: "wamid.text", timestamp: "1700000000", type: "text", text: { body: "Chablis 2022 à 18 €" } }
  end

  def image_message
    { from: "33612345678", id: "wamid.img", timestamp: "1700000000", type: "image", image: { id: "img-1", mime_type: "image/jpeg", caption: "Prix 18 €" } }
  end

  def audio_message
    { from: "33612345678", id: "wamid.aud", timestamp: "1700000001", type: "audio", audio: { id: "aud-1", mime_type: "audio/ogg; codecs=opus", voice: true } }
  end
end
