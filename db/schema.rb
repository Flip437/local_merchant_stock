# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_19_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admins", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "inbound_messages", force: :cascade do |t|
    t.bigint "merchant_id"
    t.bigint "product_id"
    t.string "sender_number", null: false
    t.string "whatsapp_message_id"
    t.integer "message_type", null: false
    t.text "raw_content"
    t.text "transcribed_content"
    t.integer "processing_status", default: 0, null: false
    t.text "error_message"
    t.datetime "received_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "whatsapp_media_id"
    t.index ["merchant_id", "processing_status"], name: "index_inbound_messages_on_merchant_id_and_processing_status"
    t.index ["merchant_id"], name: "index_inbound_messages_on_merchant_id"
    t.index ["product_id"], name: "index_inbound_messages_on_product_id"
    t.index ["whatsapp_message_id"], name: "index_inbound_messages_on_whatsapp_message_id", unique: true, where: "(whatsapp_message_id IS NOT NULL)"
  end

  create_table "merchants", force: :cascade do |t|
    t.string "name", null: false
    t.string "address"
    t.string "city", null: false
    t.string "city_slug", null: false
    t.string "zip_code"
    t.string "slug", null: false
    t.string "email"
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "otp_code_digest"
    t.datetime "otp_expires_at"
    t.integer "otp_attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["city_slug", "slug"], name: "index_merchants_on_city_slug_and_slug", unique: true
    t.index ["email"], name: "index_merchants_on_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["reset_password_token"], name: "index_merchants_on_reset_password_token", unique: true
  end

  create_table "phone_numbers", force: :cascade do |t|
    t.bigint "merchant_id", null: false
    t.string "number", null: false
    t.boolean "primary", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["merchant_id"], name: "index_phone_numbers_on_merchant_id"
    t.index ["merchant_id"], name: "index_phone_numbers_one_primary_per_merchant", unique: true, where: "(\"primary\" = true)"
    t.index ["number"], name: "index_phone_numbers_on_number", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.bigint "merchant_id", null: false
    t.bigint "category_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "meta_description"
    t.decimal "price", precision: 10, scale: 2
    t.integer "stock", default: 1, null: false
    t.integer "status", default: 0, null: false
    t.string "slug", null: false
    t.integer "views_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["merchant_id", "slug"], name: "index_products_on_merchant_id_and_slug", unique: true
    t.index ["merchant_id"], name: "index_products_on_merchant_id"
    t.index ["status"], name: "index_products_on_status"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "inbound_messages", "merchants"
  add_foreign_key "inbound_messages", "products"
  add_foreign_key "phone_numbers", "merchants"
  add_foreign_key "products", "categories"
  add_foreign_key "products", "merchants"
end
