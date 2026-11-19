class Product < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: [ :scoped, :sequentially_slugged ], scope: :merchant

  include PgSearch::Model
  pg_search_scope :search, against: { title: "A", description: "B" },
                           using: { tsearch: { dictionary: "french", prefix: true } }

  belongs_to :merchant
  belongs_to :category
  has_many_attached :images
  has_many :inbound_messages, dependent: :nullify

  enum :status, { published: 0, archived: 1 }

  validates :title, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def in_stock? = stock.positive?
end
