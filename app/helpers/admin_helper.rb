# frozen_string_literal: true

module AdminHelper
  # ステータスバッジを生成
  def status_badge(active:, label_active: "有効", label_inactive: "無効")
    css_class = active ? "bg-green-100 text-green-800" : "bg-gray-100 text-gray-800"
    label = active ? label_active : label_inactive
    
    content_tag(:span, label, class: "px-2 inline-flex text-xs leading-5 font-semibold rounded-full #{css_class}")
  end

  # 受付表示ステータスバッジを生成
  def visitor_visibility_badge(visible:)
    if visible
      content_tag(:span, "受付表示", class: "px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-purple-100 text-purple-800")
    else
      content_tag(:span, "受付非表示", class: "px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-orange-100 text-orange-800")
    end
  end

  # アイコン付きボタンを生成
  def icon_button(text, path, options = {})
    icon = options.delete(:icon)
    confirm_message = options.delete(:confirm)
    css_classes = options.delete(:class) || "px-4 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-semibold flex items-center gap-2"
    
    data_attrs = {}
    data_attrs[:turbo_confirm] = confirm_message if confirm_message
    
    button_to(path, { **options, class: css_classes, data: data_attrs }) do
      concat(icon) if icon
      concat(content_tag(:span, text))
    end
  end

  # アバターアイコンを生成
  def avatar_icon(name, size: "w-10 h-10", gradient: "from-blue-400 to-purple-500")
    content_tag(:div, class: "#{size} rounded-full bg-gradient-to-br #{gradient} flex items-center justify-center text-white font-bold") do
      name[0]
    end
  end

  # 空状態のメッセージを生成
  def empty_state(icon:, title:, description: nil)
    content_tag(:div, class: "p-12 text-center") do
      concat(
        content_tag(:div, class: "w-16 h-16 mx-auto bg-gray-100 rounded-full flex items-center justify-center mb-4") do
          raw(icon)
        end
      )
      concat(content_tag(:p, title, class: "text-gray-500 text-lg"))
      concat(content_tag(:p, description, class: "text-gray-400 text-sm mt-2")) if description
    end
  end
end

