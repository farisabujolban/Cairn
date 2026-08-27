require "test_helper"

class SessionTest < ActiveSupport::TestCase
  # The session id in the cookie is resolved straight to a user. A session with
  # no user would authenticate a request as nobody rather than failing closed.
  test "is invalid without a user" do
    session = Session.new(ip_address: "127.0.0.1", user_agent: "test")
    assert_not session.valid?
    assert_includes session.errors[:user], "must exist"
  end

  # Signing out destroys one session. It must not take the account — or the
  # user's other signed-in devices — with it.
  test "destroying a session leaves the user and their other sessions intact" do
    user = users(:one)
    kept = user.sessions.create!(ip_address: "10.0.0.1", user_agent: "phone")
    ended = user.sessions.create!(ip_address: "10.0.0.2", user_agent: "laptop")

    ended.destroy

    assert User.exists?(user.id)
    assert Session.exists?(kept.id)
  end

  # Current.user is how every controller and policy identifies the requester, so
  # it must resolve through the session rather than being set independently.
  test "Current.user resolves through the current session" do
    session = users(:two).sessions.create!(ip_address: "10.0.0.3", user_agent: "test")
    Current.session = session

    assert_equal users(:two), Current.user
  ensure
    Current.session = nil
  end
end
