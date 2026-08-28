require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  # Every task screen sits behind sign-in, like every other project screen.
  test "redirects a signed-out visitor to sign in" do
    get project_story_tasks_url(projects(:apollo), stories(:countdown))
    assert_redirected_to new_session_path
  end

  # The listing is one story's own tasks in position order — the ordering the
  # backlog tree will reuse in Phase 5.
  test "index lists the story's tasks in position order" do
    sign_in_as users(:one)

    get project_story_tasks_url(projects(:apollo), stories(:countdown))

    assert_response :success
    assert_match(/#{tasks(:wire_the_clock).title}.*#{tasks(:hold_at_t_minus).title}/m, response.body)
  end

  # 404 rather than 403: the task list of a project a user is not in must not
  # confirm the project exists.
  test "index returns 404 for a non-member" do
    sign_in_as users(:admin)

    get project_story_tasks_url(projects(:apollo), stories(:countdown))

    assert_response :not_found
  end

  # The story is looked up through the project's epics, so another project's
  # story id in this project's path resolves to nothing.
  test "index returns 404 for a story belonging to a different project" do
    sign_in_as users(:one)

    get project_story_tasks_url(projects(:apollo), stories(:gemini_docking))

    assert_response :not_found
  end

  test "show renders for a viewer" do
    sign_in_as users(:two)

    get project_task_url(projects(:apollo), tasks(:wire_the_clock))

    assert_response :success
    assert_match tasks(:wire_the_clock).title, response.body
  end

  # Member routes drop the story from the path but not the project: the lookup
  # runs through this project's stories, so another project's task is invisible
  # here even to someone who is a member of both.
  test "show returns 404 for a task belonging to a different project" do
    sign_in_as users(:one)

    get project_task_url(projects(:apollo), tasks(:gemini_latch))

    assert_response :not_found
  end

  # Per the §4 matrix, filing tasks is member-level work.
  test "create is allowed for a member and appends to the story" do
    sign_in_as users(:one)

    assert_difference -> { stories(:abort_switch).tasks.count }, 1 do
      post project_story_tasks_url(projects(:apollo), stories(:abort_switch)), params: { task: { title: "Guard the switch" } }
    end

    task = stories(:abort_switch).tasks.ordered.last
    assert_equal "Guard the switch", task.title
    assert_redirected_to project_task_url(projects(:apollo), task)
  end

  test "create accepts an assignee from the same project" do
    sign_in_as users(:one)

    post project_story_tasks_url(projects(:apollo), stories(:countdown)),
         params: { task: { title: "Assigned work", assignee_id: users(:two).id } }

    assert_equal users(:two), Task.find_by!(title: "Assigned work").assignee
  end

  # A non-member cannot be handed work in a project they cannot see.
  test "create rejects an assignee who is not a member of the project" do
    sign_in_as users(:one)

    assert_no_difference -> { Task.count } do
      post project_story_tasks_url(projects(:apollo), stories(:countdown)),
           params: { task: { title: "Assigned to a stranger", assignee_id: users(:admin).id } }
    end

    assert_response :unprocessable_content
  end

  # "Member" is the floor the matrix draws for changing work, so it is tested
  # with a user who holds exactly that role rather than an owner standing in.
  test "create is allowed for a user whose role is member" do
    sign_in_as apollo_user(:member)

    assert_difference -> { stories(:countdown).tasks.count }, 1 do
      post project_story_tasks_url(projects(:apollo), stories(:countdown)), params: { task: { title: "Solder the relay" } }
    end
  end

  # The button and the permission behind it are now one question asked of one
  # policy, so a viewer is never offered a control that would only 403.
  test "index hides the new task button from a viewer and shows it to a member" do
    sign_in_as apollo_user(:viewer)
    get project_story_tasks_url(projects(:apollo), stories(:countdown))
    assert_select "a[href=?]", new_project_story_task_path(projects(:apollo), stories(:countdown)), count: 0

    sign_in_as apollo_user(:member)
    get project_story_tasks_url(projects(:apollo), stories(:countdown))
    assert_select "a[href=?]", new_project_story_task_path(projects(:apollo), stories(:countdown))
  end

  test "show hides the edit and delete controls from a viewer" do
    sign_in_as apollo_user(:viewer)

    get project_task_url(projects(:apollo), tasks(:wire_the_clock))

    assert_select "a[href=?]", edit_project_task_path(projects(:apollo), tasks(:wire_the_clock)), count: 0
    assert_select "form[action=?]", project_task_path(projects(:apollo), tasks(:wire_the_clock)), count: 0
  end

  test "new is forbidden for a viewer" do
    sign_in_as users(:two)

    get new_project_story_task_url(projects(:apollo), stories(:countdown))

    assert_response :forbidden
  end

  # A form with no way out is a dead end. Cancel returns to the list the form
  # was opened from.
  test "new offers a cancel link back to the task list" do
    sign_in_as users(:one)

    get new_project_story_task_url(projects(:apollo), stories(:countdown))

    assert_select "a[href=?]", project_story_tasks_path(projects(:apollo), stories(:countdown)), text: "Cancel"
  end

  # Cancelling an edit returns to the record being edited, not to the list —
  # that is the screen the Edit button was pressed on.
  test "edit offers a cancel link back to the task" do
    sign_in_as users(:one)

    get edit_project_task_url(projects(:apollo), tasks(:hold_at_t_minus))

    assert_select "a[href=?]", project_task_path(projects(:apollo), tasks(:hold_at_t_minus)), text: "Cancel"
  end

  # A viewer has no create button, but the form is trivially reconstructed by
  # hand — so the check cannot live in the view.
  test "create is forbidden for a viewer" do
    sign_in_as users(:two)

    assert_no_difference -> { Task.count } do
      post project_story_tasks_url(projects(:apollo), stories(:countdown)), params: { task: { title: "Snuck in" } }
    end

    assert_response :forbidden
  end

  test "create re-renders with errors when the task is invalid" do
    sign_in_as users(:one)

    assert_no_difference -> { Task.count } do
      post project_story_tasks_url(projects(:apollo), stories(:countdown)), params: { task: { title: "" } }
    end

    assert_response :unprocessable_content
  end

  # Mass assignment guard, and the §6 guard at the request layer: the story
  # comes from the path, so a task cannot be re-parented by posting an id.
  test "create ignores a story_id smuggled in through the form" do
    sign_in_as users(:one)

    post project_story_tasks_url(projects(:apollo), stories(:countdown)),
         params: { task: { title: "Relocated", story_id: stories(:abort_switch).id } }

    assert_equal stories(:countdown), Task.find_by!(title: "Relocated").story
  end

  # Status is set manually at every level (§3 rules out rollup), so changing it
  # is an ordinary update rather than a side effect of anything else.
  test "update changes the status for a member" do
    sign_in_as users(:one)

    patch project_task_url(projects(:apollo), tasks(:wire_the_clock)), params: { task: { status: "done" } }

    assert_redirected_to project_task_url(projects(:apollo), tasks(:wire_the_clock))
    assert tasks(:wire_the_clock).reload.done?
  end

  # The direct-PATCH case from §4: a viewer bypassing the UI entirely.
  test "update is forbidden for a viewer" do
    sign_in_as users(:two)

    patch project_task_url(projects(:apollo), tasks(:wire_the_clock)), params: { task: { title: "Vandalised" } }

    assert_response :forbidden
    assert_not_equal "Vandalised", tasks(:wire_the_clock).reload.title
  end

  test "destroy removes the task for a member and returns to the story" do
    sign_in_as users(:one)

    assert_difference -> { Task.count }, -1 do
      delete project_task_url(projects(:apollo), tasks(:wire_the_clock))
    end

    assert_redirected_to project_story_tasks_url(projects(:apollo), stories(:countdown))
  end

  test "destroy is forbidden for a viewer" do
    sign_in_as users(:two)

    assert_no_difference -> { Task.count } do
      delete project_task_url(projects(:apollo), tasks(:wire_the_clock))
    end

    assert_response :forbidden
  end

  # A role in one project grants nothing in another, and a non-member gets the
  # same 404 whether the task exists or not.
  test "destroy returns 404 for a non-member rather than revealing the task" do
    sign_in_as users(:admin)

    assert_no_difference -> { Task.count } do
      delete project_task_url(projects(:apollo), tasks(:wire_the_clock))
    end

    assert_response :not_found
  end
  # The backlog tree changes status in place, so the answer has to be the one
  # control that changed. A redirect would hand the frame a whole page with no
  # matching frame in it, and Turbo would blank the control instead.
  test "an inline status change from the tree answers with the status control" do
    sign_in_as apollo_user(:member)
    record = tasks(:wire_the_clock)

    patch project_task_url(projects(:apollo), tasks(:wire_the_clock)),
          params: { task: { status: "done" } },
          headers: { "Turbo-Frame" => dom_id(record, :status) }

    assert_response :success
    assert_equal "done", record.reload.status
    assert_select "turbo-frame##{dom_id(record, :status)} select[name=?]", "task[status]"
  end

  # A rejected change has to answer inside the frame too, showing what is
  # actually stored. Re-rendering the edit page there would replace one status
  # select with an entire form, inside a control two lines high.
  test "a rejected inline status change answers inside the frame" do
    sign_in_as apollo_user(:member)
    record = tasks(:wire_the_clock)
    was = record.status

    patch project_task_url(projects(:apollo), tasks(:wire_the_clock)),
          params: { task: { status: "shipped-ish" } },
          headers: { "Turbo-Frame" => dom_id(record, :status) }

    assert_response :unprocessable_content
    assert_equal was, record.reload.status
    assert_select "turbo-frame##{dom_id(record, :status)}"
  end

  # A viewer reads the tree and changes nothing in it. The control is absent,
  # and the request behind it is refused whether or not the control was shown.
  test "a viewer is refused an inline status change" do
    sign_in_as apollo_user(:viewer)
    record = tasks(:wire_the_clock)
    was = record.status

    patch project_task_url(projects(:apollo), tasks(:wire_the_clock)),
          params: { task: { status: "done" } },
          headers: { "Turbo-Frame" => dom_id(record, :status) }

    assert_response :forbidden
    assert_equal was, record.reload.status
  end
end
