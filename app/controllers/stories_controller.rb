class StoriesController < ApplicationController
  include ProjectScoped

  before_action :set_epic, only: %i[ index new create ]
  before_action :set_story, only: %i[ show edit update destroy ]

  def index
    @stories = policy_scope(@epic.stories).ordered
  end

  def show
  end

  def new
    @story = authorize @epic.stories.new
  end

  def create
    @story = authorize @epic.stories.new(story_params)

    if @story.save
      redirect_to project_story_path(@project, @story), notice: "Story created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @story.update(story_params)
      redirect_to project_story_path(@project, @story), notice: "Story updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @story.destroy

    redirect_to project_epic_stories_path(@project, @story.epic), notice: "Story deleted."
  end

  private
    # Looked up through the project rather than globally, so another project's
    # epic id in this project's path resolves to nothing.
    def set_epic
      @epic = @project.epics.find(params[:epic_id])
    end

    # The member routes carry no epic id, so the scope comes from the project's
    # epics: a story outside them is not found rather than forbidden. The policy
    # then answers the role question on the record that was found.
    def set_story
      @story = authorize Story.where(epic: @project.epics).find(params[:id])
      @epic = @story.epic
    end

    # milestone_id and assignee_id are permitted because the form sets them.
    # Story validates both against this project, so a foreign id is rejected
    # rather than silently stored.
    def story_params
      params.expect(story: [ :title, :description, :status, :milestone_id, :assignee_id ])
    end
end
