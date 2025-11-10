FactoryBot.define do
  factory :department do
    sequence(:name) { |n| "部署#{n}" }
    position { 0 }
  end
end
