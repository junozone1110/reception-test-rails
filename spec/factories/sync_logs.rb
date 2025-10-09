FactoryBot.define do
  factory :sync_log do
    service { "MyString" }
    status { "MyString" }
    details { "" }
    error_message { "MyText" }
    synced_at { "2025-10-09 16:19:04" }
  end
end
