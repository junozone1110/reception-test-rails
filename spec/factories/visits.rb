FactoryBot.define do
  factory :visit do
    association :employee
    notes { "訪問メモ" }
    status { "pending" }
    slack_message_ts { nil }

    trait :going_now do
      status { "going_now" }
    end

    trait :waiting do
      status { "waiting" }
    end

    trait :no_match do
      status { "no_match" }
    end

    trait :with_slack_message do
      slack_message_ts { "1234567890.123456" }
    end
  end
end
