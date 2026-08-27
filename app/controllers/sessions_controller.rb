class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  # The guard above ApplicationController has nothing to check here: signing in
  # happens before there is a signed-in user to hold a role, and these actions
  # reach no project-scoped collection. Lifting it is spelled out rather than
  # implied so that it stays a deliberate exception of exactly two controllers.
  skip_after_action :verify_authorization_performed
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
