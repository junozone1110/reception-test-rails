module ApplicationHelper
  # フラッシュメッセージのCSSクラスを返す
  def flash_class(level)
    case level.to_sym
    when :notice
      "bg-green-100 border-green-400 text-green-700"
    when :success
      "bg-green-100 border-green-400 text-green-700"
    when :error, :alert
      "bg-red-100 border-red-400 text-red-700"
    when :warning
      "bg-yellow-100 border-yellow-400 text-yellow-700"
    else
      "bg-blue-100 border-blue-400 text-blue-700"
    end
  end

  # ページタイトルを設定
  def page_title(title = nil)
    base_title = "訪問者受付システム"
    title.present? ? "#{title} | #{base_title}" : base_title
  end

  # アクティブなナビゲーションリンクのクラス
  def active_link_class(path)
    current_page?(path) ? "text-blue-600 font-semibold" : "text-gray-700"
  end
end
