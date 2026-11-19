require "test_helper"

class InboundBatchJobTest < ActiveJob::TestCase
  setup { @merchant = create_merchant }

  test "skips when a newer pending message exists (debounce)" do
    first = inbound(created_at: 30.seconds.ago)
    inbound(created_at: 10.seconds.ago)

    with_processor_spy do |calls|
      InboundBatchJob.perform_now(first)
      assert_empty calls
    end
    assert first.reload.pending?
  end

  test "takes the whole pending batch when triggered by the latest message" do
    first = inbound(created_at: 30.seconds.ago)
    last = inbound(created_at: 10.seconds.ago)
    already_done = inbound(created_at: 1.hour.ago, processing_status: :processed)

    with_processor_spy do |calls|
      InboundBatchJob.perform_now(last)
      assert_equal 1, calls.size
      assert_equal [ first, last ].map(&:id), calls.first.map(&:id)
    end
    assert first.reload.processing?
    assert last.reload.processing?
    assert already_done.reload.processed?
  end

  test "does nothing when the trigger was already processed" do
    trigger = inbound(created_at: 10.seconds.ago, processing_status: :processed)
    with_processor_spy do |calls|
      InboundBatchJob.perform_now(trigger)
      assert_empty calls
    end
  end

  private

  def inbound(created_at:, processing_status: :pending)
    @merchant.inbound_messages.create!(sender_number: "+33612345678", message_type: :text, raw_content: "x",
                                       received_at: created_at, created_at: created_at, processing_status: processing_status)
  end

  # Replaces InboundBatchProcessor#call to capture the batches it receives.
  def with_processor_spy
    calls = []
    original = InboundBatchProcessor.instance_method(:call)
    InboundBatchProcessor.define_method(:call) { calls << @messages }
    yield calls
  ensure
    InboundBatchProcessor.define_method(:call, original)
  end
end
