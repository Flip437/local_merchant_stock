class Merchant < ApplicationRecord
  extend FriendlyId
  # Slug is unique per city: /lyon/cave-du-coin and /paris/cave-du-coin can coexist.
  # city_slug must be set before FriendlyId generates the slug, hence the prepend.
  before_validation :set_city_slug, prepend: true
  friendly_id :name, use: [ :scoped, :sequentially_slugged ], scope: :city_slug

  # Email is optional: merchants log in by SMS OTP first, then set email + password.
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  has_many :phone_numbers, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :inbound_messages, dependent: :nullify

  validates :name, :city, presence: true

  def primary_phone_number
    phone_numbers.find_by(primary: true)
  end

  def to_param = slug

  # The city is part of the URL anyway: moving city regenerates the slug within the new city.
  def should_generate_new_friendly_id?
    slug.blank? || will_save_change_to_city_slug?
  end

  protected

  def email_required? = false
  def password_required? = encrypted_password.present? ? super : password.present?

  private

  def set_city_slug
    self.city_slug = city.to_s.parameterize if city.present?
  end
end
