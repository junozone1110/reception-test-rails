class AdminUser < ApplicationRecord
  has_secure_password

  validates :email, presence: true, 
                    uniqueness: { case_sensitive: false }, 
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    length: { maximum: 255 }
  validates :name, presence: true, length: { maximum: 100 }
  validates :password, length: { minimum: 6 }, if: -> { password.present? }

  # メールアドレスを小文字に正規化
  before_save :normalize_email

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
end
