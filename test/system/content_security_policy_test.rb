require "application_system_test_case"

# The policy shipped report-only in phase 7 and is enforcing since phase 8 (§5,
# §13). This test is what made that flip safe, and it is what keeps enforcement
# safe now: a violation is no longer a line in a console, it is a script that
# does not run or a stylesheet that does not apply, on a page that otherwise
# looks finished.
#
# It works the same under either mode, because the browser fires
# securitypolicyviolation whether or not it also blocks. Every screen is loaded
# and every violation the browser raises is collected, so nothing here can pass
# by the policy being too permissive to notice.
#
# **A new screen is not finished until it is in the list below.** This is the
# only thing standing between an enforcing policy and a page that renders
# without its behaviour.
class ContentSecurityPolicyTest < ApplicationSystemTestCase
  setup do
    capture_violations_on_every_page
    sign_in_as users(:one)
  end

  test "no screen violates the content security policy" do
    project = projects(:apollo)
    story = stories(:countdown)

    screens = {
      "the project list" => projects_path,
      "the archived project list" => projects_path(status: "archived"),
      "the backlog tree" => project_path(project),
      "the epic list" => project_epics_path(project),
      "an epic" => project_epic_path(project, epics(:launch)),
      "the epic form" => new_project_epic_path(project),
      "the story list" => project_epic_stories_path(project, epics(:launch)),
      "a story" => project_story_path(project, story),
      "the task list" => project_story_tasks_path(project, story),
      "the milestone list" => project_milestones_path(project),
      "a milestone" => project_milestone_path(project, milestones(:v1)),
      "the member list" => project_memberships_path(project),
      "the project form" => edit_project_path(project)
    }

    violations = screens.flat_map { |name, path| violations_on(name, path) }

    assert_empty violations, "the policy is enforcing, so each of these is " \
                             "something the browser refused to load or run:\n  " \
                             "#{violations.join("\n  ")}"
  end

  # The progress bar sets its width from a percentage only known at render time,
  # and a style attribute is governed by style-src-attr. It is the one place in
  # the app where a CSP decision and a template meet, so it gets its own check
  # rather than being buried in the sweep above.
  test "the progress bar renders its width without violating the policy" do
    # Half the stories done, so the bar has a width to lose. At 0% an empty bar
    # would prove nothing — which is what the first version of this test did.
    stories(:countdown).update!(status: :done)

    violations = violations_on("an epic with progress", project_epic_path(projects(:apollo), epics(:launch)))

    assert_empty violations
    assert_operator rendered_progress_width, :>, 0,
      "the bar has no width, so whatever sets it was blocked or never applied"
  end

  private
    # Installed through CDP rather than with execute_script, and the difference
    # is the whole test. A violation fires while the document is being parsed,
    # and every visit replaces the document — so a listener added after a page
    # loads has already missed everything on it, and one added before is
    # destroyed by the next navigation. addScriptToEvaluateOnNewDocument runs
    # ahead of the page's own content, on every document, for the life of the
    # browser.
    #
    # Without this the sweep below cannot fail: it reads an array that a fresh
    # document never populated, finds it empty, and reports success.
    def capture_violations_on_every_page
      page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: <<~JS)
        window.__cspViolations = [];
        document.addEventListener("securitypolicyviolation", event => {
          window.__cspViolations.push(
            event.violatedDirective + " blocked " + (event.blockedURI || "inline"));
        });
      JS
    end

    # Collected from the browser rather than from the response headers: only the
    # browser knows what the policy actually refused.
    def violations_on(screen, path)
      visit path
      assert_selector "main"

      page.evaluate_script("window.__cspViolations || []").uniq.map { |v| "#{screen}: #{v}" }
    end

    def rendered_progress_width
      page.evaluate_script(<<~JS)
        (() => {
          const bar = document.querySelector("[role=progressbar] > div");
          return bar ? bar.getBoundingClientRect().width : 0;
        })()
      JS
    end
end
