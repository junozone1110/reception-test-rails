require 'rails_helper'

# エラークラスを明示的にrequire
require_relative '../../app/errors/application_errors'

RSpec.describe VisitService, type: :service do
  let(:department) { create(:department) }
  let(:employee) { create(:employee, department: department) }
  let(:visit_params) do
    {
      employee_id: employee.id,
      notes: 'テスト訪問'
    }
  end
  let(:session) { {} }
  let(:service) { described_class.new }

  before do
    allow(AppConfig::Slack).to receive(:bot_token?).and_return(true)
    allow(AppConfig::Slack).to receive(:channel_id?).and_return(true)
  end

  describe '#create_visit' do
    context 'with valid parameters' do
      it 'creates a visit' do
        expect {
          service.create_visit(visit_params, session: session)
        }.to change(Visit, :count).by(1)
      end

      it 'enqueues Slack notification job' do
        expect {
          service.create_visit(visit_params, session: session)
        }.to have_enqueued_job(SlackNotificationJob)
      end

      it 'stores visit_id in session' do
        visit = service.create_visit(visit_params, session: session)
        expect(session[:last_visit_id]).to eq(visit.id)
      end

      it 'returns created visit' do
        visit = service.create_visit(visit_params, session: session)
        expect(visit).to be_a(Visit)
        expect(visit.employee).to eq(employee)
        expect(visit.notes).to eq('テスト訪問')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) { { employee_id: nil, notes: 'テスト' } }

      it 'raises VisitCreationError' do
        expect {
          service.create_visit(invalid_params, session: session)
        }.to raise_error(VisitCreationError)
      end
    end

    context 'when employee does not exist' do
      let(:invalid_params) { { employee_id: 999999, notes: 'テスト' } }

      it 'raises VisitCreationError' do
        expect {
          service.create_visit(invalid_params, session: session)
        }.to raise_error(VisitCreationError)
      end
    end
  end
end

