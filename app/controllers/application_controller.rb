class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # エラーハンドリング
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActionController::ParameterMissing, with: :parameter_missing

  private

  def record_not_found
    redirect_to root_path, alert: "お探しのページが見つかりませんでした"
  end

  def parameter_missing(exception)
    Rails.logger.error "Parameter missing: #{exception.message}"
    redirect_to root_path, alert: "不正なリクエストです"
  end
end
