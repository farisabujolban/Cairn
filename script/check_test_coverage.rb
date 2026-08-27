#!/usr/bin/env ruby
# Fails the build when a model, controller, policy or helper has no test file.
#
# The spec's TDD rule is "never write implementation code for a class whose test
# file does not yet exist". Discipline erodes over a long build, so this checks
# it mechanically the same way a NOT NULL column enforces the no-subtasks rule.

APP_ROOT = File.expand_path("..", __dir__)

# Classes that are framework plumbing rather than behaviour we author.
EXEMPT = %w[
  app/models/application_record.rb
  app/models/current.rb
  app/controllers/application_controller.rb
  app/channels/application_cable/connection.rb
  app/channels/application_cable/channel.rb
  app/helpers/application_helper.rb
  app/jobs/application_job.rb
  app/mailers/application_mailer.rb
].freeze

RULES = [
  { source: "app/models",      test: "test/models",      label: "model" },
  { source: "app/controllers", test: "test/controllers",  label: "controller" },
  { source: "app/policies",    test: "test/policies",     label: "policy" },
  { source: "app/helpers",     test: "test/helpers",      label: "helper" }
].freeze

missing = RULES.flat_map do |rule|
  Dir[File.join(APP_ROOT, rule[:source], "**", "*.rb")].sort.filter_map do |path|
    relative = path.delete_prefix("#{APP_ROOT}/")
    next if EXEMPT.include?(relative)
    next if relative.include?("/concerns/")

    name = relative.delete_prefix("#{rule[:source]}/").delete_suffix(".rb")
    test_path = File.join(rule[:test], "#{name}_test.rb")
    next if File.exist?(File.join(APP_ROOT, test_path))

    "  #{relative} (#{rule[:label]}) has no #{test_path}"
  end
end

if missing.empty?
  puts "Test coverage guard: every model, controller, policy and helper has a test file."
  exit 0
else
  warn "Test coverage guard failed — these classes have no test file:"
  warn missing.join("\n")
  warn "\nWrite the test first (SPEC.md §9), then the implementation."
  exit 1
end
