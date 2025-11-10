require 'rails_helper'

RSpec.describe Visit, type: :model do
  describe 'associations' do
    it { should belong_to(:employee) }
  end

  describe 'validations' do
    subject { build(:visit) }

    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:employee) }
  end

  describe 'enums' do
    it 'defines status enum with correct values' do
      expect(Visit.statuses).to eq({
        'pending' => 'pending',
        'going_now' => 'going_now',
        'waiting' => 'waiting',
        'no_match' => 'no_match'
      })
    end

    it 'generates status_pending? method' do
      visit = build(:visit, status: 'pending')
      expect(visit.status_pending?).to be true
    end

    it 'generates status_going_now? method' do
      visit = build(:visit, status: 'going_now')
      expect(visit.status_going_now?).to be true
    end
  end

  describe 'scopes' do
    let!(:recent_visit) { create(:visit, created_at: 1.day.ago) }
    let!(:old_visit) { create(:visit, created_at: 1.week.ago) }
    let!(:today_visit) { create(:visit, created_at: Time.current) }
    let!(:pending_visit) { create(:visit, status: 'pending') }
    let!(:responded_visit) { create(:visit, status: 'going_now') }

    describe '.recent' do
      it 'returns visits ordered by created_at desc' do
        recent_visits = Visit.recent.limit(3)
        expect(recent_visits).to include(today_visit)
        expect(recent_visits.first.created_at).to be >= recent_visits.last.created_at
      end
    end

    describe '.today' do
      it 'returns visits created today' do
        expect(Visit.today).to include(today_visit)
        expect(Visit.today).not_to include(recent_visit)
      end
    end

    describe '.responded' do
      it 'returns visits that are not pending' do
        expect(Visit.responded).to include(responded_visit)
        expect(Visit.responded).not_to include(pending_visit)
      end
    end
  end

  describe '#responded?' do
    it 'returns false for pending visit' do
      visit = build(:visit, status: 'pending')
      expect(visit.responded?).to be false
    end

    it 'returns true for non-pending visit' do
      visit = build(:visit, status: 'going_now')
      expect(visit.responded?).to be true
    end
  end

  describe '#status_text' do
    it 'returns correct text for pending' do
      visit = build(:visit, status: 'pending')
      expect(visit.status_text).to eq('確認待ち')
    end

    it 'returns correct text for going_now' do
      visit = build(:visit, status: 'going_now')
      expect(visit.status_text).to eq('すぐ行きます')
    end

    it 'returns correct text for waiting' do
      visit = build(:visit, status: 'waiting')
      expect(visit.status_text).to eq('お待ちいただく')
    end

    it 'returns correct text for no_match' do
      visit = build(:visit, status: 'no_match')
      expect(visit.status_text).to eq('心当たりがない')
    end

    it 'returns default text for unknown status' do
      # enumのバリデーションにより、直接unknownを設定できないため
      # STATUS_TEXTSに存在しない値の場合のテストは、クラスメソッドで確認
      expect(Visit.status_text_for('unknown')).to eq('確認済み')
    end
  end

  describe '.status_text_for' do
    it 'returns correct text for status string' do
      expect(Visit.status_text_for('going_now')).to eq('すぐ行きます')
    end

    it 'returns correct text for status symbol' do
      expect(Visit.status_text_for(:waiting)).to eq('お待ちいただく')
    end
  end

  describe '#formatted_created_at' do
    it 'formats created_at correctly' do
      visit = create(:visit, created_at: Time.zone.local(2025, 11, 10, 14, 30))
      expect(visit.formatted_created_at).to eq('2025年11月10日 14:30')
    end
  end
end
