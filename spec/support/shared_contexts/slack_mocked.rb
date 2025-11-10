# frozen_string_literal: true

# Slack APIをモックするためのshared context
RSpec.shared_context 'with slack mocked' do
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
end

