# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/activation_needed_email
  def activation_needed_email
    UserMailer.activation_needed_email(User.first)
  end

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/activation_success_email
  def activation_success_email
    UserMailer.activation_success_email(User.first)
  end

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/reset_password_email
  def reset_password_email
    UserMailer.reset_password_email(User.first)
  end

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/newsletter
  def newsletter
    UserMailer.newsletter(User.first, "Test Subject", "This is a test body")
  end

end
