module EmployeesHelper
  # 従業員のアバター画像URLを取得
  def employee_avatar_url(employee)
    employee.avatar_url.presence || default_avatar_url(employee.name)
  end

  # デフォルトのアバターURLを生成
  def default_avatar_url(name)
    "https://ui-avatars.com/api/?name=#{URI.encode_www_form_component(name)}&background=random&color=fff&size=128"
  end

  # 従業員のイニシャルを取得
  def employee_initials(employee)
    employee.name.split.map(&:first).join.upcase[0..1]
  end

  # ステータスバッジを表示
  def employee_status_badge(employee)
    if employee.is_active?
      content_tag :span, "有効", class: "px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800"
    else
      content_tag :span, "無効", class: "px-2 py-1 text-xs font-semibold rounded-full bg-gray-100 text-gray-800"
    end
  end
end

