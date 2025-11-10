require 'rails_helper'

RSpec.describe SlackActionHandler, type: :service do
  let(:department) { create(:department) }
  let(:employee) { create(:employee, department: department) }
  let(:visit) { create(:visit, employee: employee, status: 'pending') }
  let(:visit_status_updater) { instance_double(VisitStatusUpdater) }
  let(:service) { described_class.new(visit_status_updater: visit_status_updater) }

  let(:payload) do
    {
      'type' => 'block_actions',
      'actions' => [{
        'action_id' => AppConfig::Slack::ACTION_GOING_NOW,
        'value' => visit.id.to_s
      }],
      'user' => {
        'id' => 'U123456',
        'name' => 'Test User'
      }
    }
  end

  before do
    allow(visit_status_updater).to receive(:update_status).and_return(visit)
    visit.update!(status: 'going_now')
  end

  describe '#handle' do
    context 'with valid payload' do
      it 'updates visit status' do
        service.handle(payload)
        expect(visit_status_updater).to have_received(:update_status).with(
          visit,
          :going_now,
          responder: 'Test User'
        )
      end

      it 'returns success result' do
        result = service.handle(payload)
        expect(result[:success]).to be true
        expect(result[:visit]).to eq(visit)
        expect(result[:status_text]).to eq('すぐ行きます')
      end
    end

    context 'with ACTION_WAITING' do
      let(:payload) do
        {
          'type' => 'block_actions',
          'actions' => [{
            'action_id' => AppConfig::Slack::ACTION_WAITING,
            'value' => visit.id.to_s
          }],
          'user' => { 'id' => 'U123456', 'name' => 'Test User' }
        }
      end

      it 'updates status to waiting' do
        service.handle(payload)
        expect(visit_status_updater).to have_received(:update_status).with(
          visit,
          :waiting,
          responder: 'Test User'
        )
      end
    end

    context 'with ACTION_NO_MATCH' do
      let(:payload) do
        {
          'type' => 'block_actions',
          'actions' => [{
            'action_id' => AppConfig::Slack::ACTION_NO_MATCH,
            'value' => visit.id.to_s
          }],
          'user' => { 'id' => 'U123456', 'name' => 'Test User' }
        }
      end

      it 'updates status to no_match' do
        service.handle(payload)
        expect(visit_status_updater).to have_received(:update_status).with(
          visit,
          :no_match,
          responder: 'Test User'
        )
      end
    end

    context 'with unknown action_id' do
      let(:payload) do
        {
          'type' => 'block_actions',
          'actions' => [{
            'action_id' => 'unknown_action',
            'value' => visit.id.to_s
          }],
          'user' => { 'id' => 'U123456' }
        }
      end

      it 'raises SlackActionError' do
        expect {
          service.handle(payload)
        }.to raise_error(SlackActionError, /Unknown action_id/)
      end
    end

    context 'when visit not found' do
      let(:payload) do
        {
          'type' => 'block_actions',
          'actions' => [{
            'action_id' => AppConfig::Slack::ACTION_GOING_NOW,
            'value' => '999999'
          }],
          'user' => { 'id' => 'U123456' }
        }
      end

      it 'raises VisitNotFoundError' do
        expect {
          service.handle(payload)
        }.to raise_error(VisitNotFoundError)
      end
    end

    context 'with nil payload' do
      it 'raises SlackPayloadError' do
        expect {
          service.handle(nil)
        }.to raise_error(SlackPayloadError, /Payload is nil/)
      end
    end

    context 'with invalid payload type' do
      it 'raises SlackPayloadError' do
        expect {
          service.handle('invalid')
        }.to raise_error(SlackPayloadError, /Payload type is invalid/)
      end
    end
  end
end

