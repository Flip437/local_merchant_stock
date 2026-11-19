# Default category used when the LLM can't match an existing one
Category.default

%w[Alimentation Boissons Mode Maison Beauté Sport Loisirs Électronique].each do |name|
  Category.find_or_create_by!(name: name)
end

if Rails.env.development?
  Admin.find_or_create_by!(email: "admin@example.test") do |admin|
    admin.password = "password123"
  end
end
