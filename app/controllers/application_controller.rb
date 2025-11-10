class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # エラーハンドリング
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActionController::ParameterMissing, with: :parameter_missing
  rescue_from ApplicationError, with: :handle_application_error

  private

  def record_not_found
    respond_to do |format|
      format.html { redirect_to root_path, alert: "お探しのページが見つかりませんでした" }
      format.json { render_error("お探しのページが見つかりませんでした", status: :not_found) }
    end
  end

  def parameter_missing(exception)
    Rails.logger.error "Parameter missing: #{exception.message}"
    respond_to do |format|
      format.html { redirect_to root_path, alert: "不正なリクエストです" }
      format.json { render_error("不正なリクエストです", status: :bad_request) }
    end
  end

  def handle_application_error(exception)
    Rails.logger.error "Application error: #{exception.class.name} - #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n") if exception.backtrace

    respond_to do |format|
      format.html { handle_html_error(exception) }
      format.json { render_error(exception.message, status: exception.status_code) }
    end
  end

  def handle_html_error(exception)
    case exception
    when VisitCreationError, VisitStatusUpdateError
      flash.now[:alert] = exception.message
      render status: exception.status_code
    when VisitNotFoundError
      redirect_to root_path, alert: exception.message
    else
      redirect_to root_path, alert: "エラーが発生しました。しばらくしてからお試しください。"
    end
  end

  def render_error(message, status: 500)
    render json: { error: message }, status: status
  end
end
