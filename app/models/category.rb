class Category < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :sequentially_slugged

  DEFAULT_NAME = "Autre"

  has_many :products, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true

  def self.default
    find_or_create_by!(name: DEFAULT_NAME)
  end
end
