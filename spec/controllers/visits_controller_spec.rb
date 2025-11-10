require 'rails_helper'

RSpec.describe VisitsController, type: :controller do
  let(:department) { create(:department) }
  let(:employee) { create(:employee, department: department) }

  describe 'GET #new' do
    context 'with valid employee_id' do
      it 'returns success' do
        get :new, params: { employee_id: employee.id }
        expect(response).to have_http_status(:success)
      end

      it 'assigns @visit' do
        get :new, params: { employee_id: employee.id }
        expect(assigns(:visit)).to be_a_new(Visit)
        expect(assigns(:visit).employee).to eq(employee)
      end
    end

    context 'when employee is not found' do
      it 'redirects to root' do
        get :new, params: { employee_id: 999999 }
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when employee is inactive' do
      let(:inactive_employee) { create(:employee, :inactive, department: department) }

      it 'redirects to root' do
        get :new, params: { employee_id: inactive_employee.id }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        visit: {
          employee_id: employee.id,
          notes: 'テスト訪問'
        }
      }
    end

    before do
      allow(AppConfig::Slack).to receive(:bot_token?).and_return(true)
      allow(AppConfig::Slack).to receive(:channel_id?).and_return(true)
    end

    context 'with valid parameters' do
      it 'creates a new visit' do
        expect {
          post :create, params: valid_params
        }.to change(Visit, :count).by(1)
      end

      it 'enqueues Slack notification job' do
        expect {
          post :create, params: valid_params
        }.to have_enqueued_job(SlackNotificationJob)
      end

      it 'redirects to complete page' do
        post :create, params: valid_params
        expect(response).to redirect_to(complete_path)
      end

      it 'stores visit_id in session' do
        post :create, params: valid_params
        expect(session[:last_visit_id]).to eq(Visit.last.id)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          visit: {
            employee_id: nil,
            notes: 'テスト'
          }
        }
      end

      it 'does not create a visit' do
        expect {
          post :create, params: invalid_params
        }.not_to change(Visit, :count)
      end

      it 'renders new template' do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'GET #complete' do
    context 'with visit_id in session' do
      let(:visit) { create(:visit, employee: employee) }

      before do
        session[:last_visit_id] = visit.id
      end

      it 'returns success' do
        get :complete
        expect(response).to have_http_status(:success)
      end

      it 'assigns @visit' do
        get :complete
        expect(assigns(:visit)).to eq(visit)
      end
    end

    context 'without visit_id in session' do
      it 'returns success' do
        get :complete
        expect(response).to have_http_status(:success)
      end

      it 'assigns nil to @visit' do
        get :complete
        expect(assigns(:visit)).to be_nil
      end
    end
  end

  describe 'GET #status' do
    let(:visit) { create(:visit, employee: employee) }

    context 'with valid visit_id' do
      it 'returns visit status as JSON' do
        get :status, params: { id: visit.id }
        expect(response).to have_http_status(:success)

        json = JSON.parse(response.body)
        expect(json['status']).to eq(visit.status)
        expect(json['status_text']).to eq(visit.status_text)
        expect(json['responded']).to eq(visit.responded?)
        expect(json['updated_at']).to be_present
      end
    end

    context 'when visit is not found' do
      it 'returns 404' do
        get :status, params: { id: 999999 }
        expect(response).to have_http_status(:not_found)

        json = JSON.parse(response.body)
        expect(json['error']).to eq('訪問記録が見つかりません')
      end
    end
  end
end

