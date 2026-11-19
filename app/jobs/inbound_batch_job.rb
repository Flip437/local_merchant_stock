# Debounced processing of a merchant's WhatsApp messages.
#
# Every incoming message schedules this job WINDOW after its arrival. When the job runs, it only
# proceeds if its trigger is still the merchant's most recent pending message: any newer message
# has scheduled its own job, which will take the whole batch. So the batch is processed 60 s after
# the merchant's last message.
class InboundBatchJob < ApplicationJob
  queue_as :default

  WINDOW = 60.seconds

  # The trigger message was deleted in the meantime: nothing to do.
  # (Processing errors are caught by InboundBatchProcessor, so the job doesn't retry and re-send replies.)
  discard_on ActiveJob::DeserializationError

  def perform(trigger)
    merchant = trigger.merchant
    return unless merchant

    batch = merchant.with_lock do
      pending = merchant.inbound_messages.pending.order(:created_at, :id).to_a
      next [] unless pending.last == trigger

      InboundMessage.where(id: pending.map(&:id)).update_all(processing_status: :processing, updated_at: Time.current)
      pending
    end

    InboundBatchProcessor.new(merchant, batch).call if batch.any?
  end
end
