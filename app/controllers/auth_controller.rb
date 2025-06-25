class AuthController < ApplicationController
  skip_before_action :require_login, only: [ :login, :authenticate ]

  def login
    # Redirect to videos index if already logged in
    redirect_to videos_path if current_user
  end

  def authenticate
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to videos_path, notice: "Logged in successfully!"
    else
      flash.now[:alert] = "Invalid email or password"
      render :login, status: :unprocessable_entity
    end
  end

  def logout
    session[:user_id] = nil
    redirect_to login_path, notice: "Logged out successfully!"
  end
end
