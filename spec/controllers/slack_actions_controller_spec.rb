require 'rails_helper'

RSpec.describe SlackActionsController, type: :controller do
  before do
    # CSRFトークンの検証をスキップ
    allow(controller).to receive(:verify_authenticity_token)
    # Slack署名検証をスキップ（テスト用）
    allow_any_instance_of(SlackSignatureVerifier).to receive(:verify).and_return(true)
  end

  let(:department) { create(:department) }
  let(:employee) { create(:employee, department: department) }
  let(:visit) { create(:visit, employee: employee, status: 'pending') }

  describe 'POST #create' do
    context 'with url_verification challenge' do
      let(:payload) do
        {
          'type' => 'url_verification',
          'challenge' => 'test_challenge_token'
        }
      end

      it 'returns challenge token' do
        post :create, params: { payload: payload.to_json }
        expect(response).to have_http_status(:success)

        json = JSON.parse(response.body)
        expect(json['challenge']).to eq('test_challenge_token')
      end
    end

    context 'with block_actions payload' do
      let(:payload) do
        {
          'type' => AppConfig::Slack::PAYLOAD_TYPE_BLOCK_ACTIONS,
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
        allow_any_instance_of(SlackActionHandler).to receive(:handle).and_return({
          success: true,
          visit: visit,
          status_text: 'すぐ行きます'
        })
        visit.update!(status: 'going_now')
      end

      it 'returns success response' do
        post :create, params: { payload: payload.to_json }
        expect(response).to have_http_status(:success)

        json = JSON.parse(response.body)
        expect(json['text']).to include('すぐ行きます')
      end
    end

    context 'with invalid JSON' do
      it 'returns bad request' do
        post :create, params: { payload: 'invalid json' }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end

