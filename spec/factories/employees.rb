FactoryBot.define do
  factory :employee do
    sequence(:name) { |n| "従業員#{n}" }
    sequence(:email) { |n| "employee#{n}@example.com" }
    sequence(:slack_user_id) { |n| "U#{n.to_s.rjust(9, '0')}" }
    association :department
    is_active { true }
    visible_to_visitors { true }
    avatar_url { nil }

    trait :inactive do
      is_active { false }
    end

    trait :hidden do
      visible_to_visitors { false }
    end

    trait :with_smarthr_id do
      sequence(:smarthr_id) { |n| "smarthr_#{n}" }
    end
  end
end
