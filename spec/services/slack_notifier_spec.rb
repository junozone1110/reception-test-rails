require 'rails_helper'

RSpec.describe SlackNotifier, type: :service do
  let(:department) { create(:department) }
  let(:employee) { create(:employee, department: department) }
  let(:visit) { create(:visit, employee: employee) }
  let(:slack_client) { instance_double(::Slack::Web::Client) }
  let(:slack_response) { { 'ok' => true, 'ts' => '1234567890.123456' } }

  before do
    allow(AppConfig::Slack).to receive(:bot_token).and_return('xoxb-test-token')
    allow(AppConfig::Slack).to receive(:bot_token?).and_return(true)
    allow(AppConfig::Slack).to receive(:channel_id).and_return('C1234567890')
    allow(AppConfig::Slack).to receive(:channel_id?).and_return(true)
    allow(::Slack::Web::Client).to receive(:new).and_return(slack_client)
    allow(slack_client).to receive(:chat_postMessage).and_return(slack_response)
    allow(slack_client).to receive(:chat_update).and_return(slack_response)
  end

  describe '#notify_visit' do
    context 'when configuration is valid' do
      it 'sends notification successfully' do
        notifier = described_class.new
        response = notifier.notify_visit(visit)

        expect(response['ok']).to be true
        expect(slack_client).to have_received(:chat_postMessage)
      end

      it 'saves message timestamp' do
        notifier = described_class.new
        notifier.notify_visit(visit)

        visit.reload
        expect(visit.slack_message_ts).to eq('1234567890.123456')
      end
    end

    context 'when bot token is not configured' do
      before do
        allow(AppConfig::Slack).to receive(:bot_token?).and_return(false)
      end

      it 'raises NotConfiguredError' do
        expect {
          described_class.new
        }.to raise_error(SlackNotifier::NotConfiguredError, /SLACK_BOT_TOKEN/)
      end
    end

    context 'when channel ID is not configured' do
      before do
        allow(AppConfig::Slack).to receive(:channel_id?).and_return(false)
      end

      it 'raises NotConfiguredError' do
        expect {
          described_class.new
        }.to raise_error(SlackNotifier::NotConfiguredError, /SLACK_CHANNEL_ID/)
      end
    end

    context 'when Slack API returns error' do
      before do
        allow(slack_client).to receive(:chat_postMessage)
          .and_raise(::Slack::Web::Api::Errors::ChannelNotFound.new('channel_not_found'))
      end

      it 'raises NotificationFailedError' do
        notifier = described_class.new

        expect {
          notifier.notify_visit(visit)
        }.to raise_error(SlackNotifier::NotificationFailedError, /channel not found/i)
      end
    end
  end

  describe '#update_message' do
    let(:visit) { create(:visit, employee: employee, slack_message_ts: '1234567890.123456') }

    it 'updates message successfully' do
      notifier = described_class.new
      response = notifier.update_message(visit, responder: 'Test User')

      expect(response['ok']).to be true
      expect(slack_client).to have_received(:chat_update)
    end
  end
end

