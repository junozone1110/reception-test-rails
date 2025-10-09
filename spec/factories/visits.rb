FactoryBot.define do
  factory :visit do
    employee { nil }
    notes { "MyText" }
    status { "MyString" }
    slack_message_ts { "MyString" }
  end
end
