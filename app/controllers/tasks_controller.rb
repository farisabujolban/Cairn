class TasksController < ApplicationController
  include ProjectScoped

  before_action :set_story, only: %i[ index new create ]
  before_action :set_task, only: %i[ show edit update destroy ]

  def index
    @tasks = policy_scope(@story.tasks).ordered
  end

  def show
  end

  def new
    @task = authorize @story.tasks.new
  end

  def create
    @task = authorize @story.tasks.new(task_params)

    if @task.save
      redirect_to project_task_path(@project, @task), notice: "Task created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @task.update(task_params)
      redirect_to project_task_path(@project, @task), notice: "Task updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @task.destroy

    redirect_to project_story_tasks_path(@project, @task.story), notice: "Task deleted."
  end

  private
    # Scoped through the project's epics, so another project's story id in this
    # project's path resolves to nothing.
    def set_story
      @story = Story.where(epic: @project.epics).find(params[:story_id])
    end

    # The member routes carry no story id, so the scope comes from the project's
    # stories: a task outside them is not found rather than forbidden. The
    # policy then answers the role question on the record that was found.
    def set_task
      @task = authorize Task.where(story: Story.where(epic: @project.epics)).find(params[:id])
      @story = @task.story
    end

    # story_id is deliberately absent: the story comes from the path, so a task
    # cannot be re-parented by posting an id (§6).
    def task_params
      params.expect(task: [ :title, :status, :assignee_id ])
    end
end
