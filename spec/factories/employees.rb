FactoryBot.define do
  factory :employee do
    name { "MyString" }
    email { "MyString" }
    slack_user_id { "MyString" }
    department { nil }
    is_active { false }
    avatar_url { "MyString" }
  end
end
