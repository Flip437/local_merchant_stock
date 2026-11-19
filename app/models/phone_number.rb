class PhoneNumber < ApplicationRecord
  belongs_to :merchant

  normalizes :number, with: ->(n) { n.to_s.gsub(/[^\d+]/, "") }

  validates :number, presence: true, uniqueness: true,
                     format: { with: /\A\+\d{8,15}\z/, message: "doit être au format international (+33…)" }
end
