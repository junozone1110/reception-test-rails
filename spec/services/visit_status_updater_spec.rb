require 'rails_helper'

RSpec.describe VisitStatusUpdater, type: :service do
  let(:department) { create(:department) }
  let(:employee) { create(:employee, department: department) }
  let(:visit) { create(:visit, employee: employee, status: 'pending') }
  let(:slack_notifier) { instance_double(SlackNotifier) }
  let(:service) { described_class.new(slack_notifier: slack_notifier) }

  before do
    allow(slack_notifier).to receive(:update_message).and_return({ 'ok' => true })
  end

  describe '#update_status' do
    context 'with pending visit' do
      it 'updates visit status' do
        service.update_status(visit, :going_now, responder: 'Test User')
        expect(visit.reload.status).to eq('going_now')
      end

      it 'calls SlackNotifier#update_message' do
        service.update_status(visit, :going_now, responder: 'Test User')
        expect(slack_notifier).to have_received(:update_message).with(
          visit,
          responder: 'Test User',
          responded_at: anything
        )
      end

      it 'returns updated visit' do
        result = service.update_status(visit, :waiting, responder: 'Test User')
        expect(result).to eq(visit)
        expect(result.status).to eq('waiting')
      end
    end

    context 'with already responded visit' do
      let(:visit) { create(:visit, :going_now, employee: employee) }

      it 'raises VisitAlreadyRespondedError' do
        expect {
          service.update_status(visit, :waiting, responder: 'Test User')
        }.to raise_error(VisitAlreadyRespondedError)
      end
    end

    context 'when Slack notification fails' do
      before do
        allow(slack_notifier).to receive(:update_message)
          .and_raise(SlackNotifier::NotificationFailedError, 'Slack error')
      end

      it 'still updates visit status' do
        service.update_status(visit, :going_now, responder: 'Test User')
        expect(visit.reload.status).to eq('going_now')
      end
    end
  end
end

