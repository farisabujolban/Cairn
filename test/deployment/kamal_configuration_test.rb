require "test_helper"
require "yaml"

# config/deploy.yml is never executed by anything in this repository, so nothing
# else here can notice when it drifts out of agreement with the app it deploys.
# Every failure it can cause looks the same from a terminal — the container comes
# up and the site does not work — and each of them costs a deploy to find.
#
# So the settings that have to agree with something else are asserted against
# that something else. What Kamal does with a correct file is Kamal's business
# and is not tested here.
class KamalConfigurationTest < ActiveSupport::TestCase
  DEPLOY = YAML.load_file(Rails.root.join("config/deploy.yml"))

  # config/environments/production.rb raises without it, so a deploy that forgets
  # this does not misbehave — it fails to boot, over and over, while the proxy
  # reports the container unhealthy.
  test "the container is given the APP_HOST production refuses to boot without" do
    assert DEPLOY.dig("env", "clear", "APP_HOST").present?,
           "production.rb raises without APP_HOST"
  end

  # The one mismatch that produces a working deploy of a broken site: the proxy
  # accepts the hostname, forwards it, and config.hosts rejects it. Every page is
  # a 403 "Blocked host", with a healthy container and a valid certificate.
  test "the proxy routes the hostname the app will accept" do
    assert_equal DEPLOY.dig("env", "clear", "APP_HOST"), DEPLOY.dig("proxy", "host"),
                 "the proxy would forward a hostname config.hosts rejects with a 403"
  end

  # production.rb sets assume_ssl and force_ssl, which together say "something in
  # front of me terminates TLS". If nothing does, every request redirects to an
  # https URL that nothing is listening on.
  test "something terminates TLS in front of the app" do
    assert_equal true, DEPLOY.dig("proxy", "ssl"),
                 "production assumes SSL is terminated in front of it"
  end

  # §12's most important line: "a container redeploy without it silently destroys
  # every project, epic, story, and task."
  test "the storage directory the database lives in is on a persistent volume" do
    assert_includes volumes.map { |volume| volume.split(":").last }, "/rails/storage",
                    "without this mount, a redeploy destroys the database"
  end

  # A host path rather than a Docker named volume, and script/backup_database is
  # the reason. It runs on the server as an ordinary process and opens the
  # database file directly, which is what lets SQLite's locks do their job while
  # the app keeps writing. A named volume is reachable only through Docker, and
  # the backup would then need the deploy tooling to be healthy on the day it is
  # needed most.
  test "the storage volume is a host path the backup script can reach" do
    host_path = volumes.find { |volume| volume.end_with?(":/rails/storage") }.split(":").first

    assert host_path.start_with?("/"),
           "#{host_path.inspect} is a named volume; script/backup_database needs a path"
  end

  test "the master key is supplied as a secret and is not in the repository" do
    assert_includes DEPLOY.dig("env", "secret"), "RAILS_MASTER_KEY"

    assert system("git", "check-ignore", "--quiet", "config/master.key",
                  chdir: Rails.root.to_s, out: File::NULL, err: File::NULL),
           "config/master.key is not gitignored"
    assert_empty `git ls-files config/master.key`.strip,
                 "config/master.key is committed"
  end

  private
    def volumes
      DEPLOY.fetch("volumes")
    end
end
