class CreateMerchants < ActiveRecord::Migration[8.1]
  def change
    create_table :merchants do |t|
      t.string :name, null: false
      t.string :address
      t.string :city, null: false
      t.string :city_slug, null: false
      t.string :zip_code
      t.string :slug, null: false

      # Devise — email is optional (added by the merchant after the first SMS login)
      t.string :email
      t.string :encrypted_password, null: false, default: ""
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at

      # SMS OTP (first login / password reset)
      t.string :otp_code_digest
      t.datetime :otp_expires_at
      t.integer :otp_attempts, null: false, default: 0

      t.timestamps
    end

    add_index :merchants, :email, unique: true, where: "email IS NOT NULL"
    add_index :merchants, :reset_password_token, unique: true
    add_index :merchants, [ :city_slug, :slug ], unique: true
  end
end
