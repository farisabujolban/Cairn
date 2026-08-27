class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # §4's mechanical half. An action that forgets to authorize, or an index that
  # forgets its scope, raises instead of quietly returning 200 — which converts
  # "we remembered to check" into "it is impossible to forget".
  after_action :verify_authorization_performed

  rescue_from Pundit::NotAuthorizedError, with: :deny_access

  private
    # Pundit's own idiom for this pair is `except: :index` and `only: :index` on
    # two separate callbacks. Naming an action in a callback that every
    # controller inherits is a trap here: raise_on_missing_callback_actions
    # turns the reference into AbstractController::ActionNotFound for any
    # controller that has no index action, and that renders as a bare 404 with
    # nothing to say why. Branching on the action instead keeps the guard armed
    # on controllers that never define an index at all.
    def verify_authorization_performed
      action_name == "index" ? verify_policy_scoped : verify_authorized
    end

    # Pundit's default is a current_user method; this app keeps the signed-in
    # user on Current instead.
    def pundit_user = Current.user

    # §4 splits denial in two, and the split is the point. A 403 confirms the
    # record exists, so a non-member gets the same 404 they would get for a
    # project that never existed — the response cannot be used to enumerate
    # what the team is working on. A member whose role is merely too low
    # already knows it exists, so hiding it would only confuse them.
    def deny_access(exception)
      project = project_for(exception.record)

      if project.nil? || !project.persisted? || member_of?(project)
        head :forbidden
      else
        head :not_found
      end
    end

    # Mirrors the policies: a record is a project, or it reaches one. An
    # unsaved record reaches a project that may or may not exist yet, which is
    # why deny_access treats "not persisted" as nothing to hide.
    def project_for(record)
      record.is_a?(Project) ? record : record.try(:project)
    end

    def member_of?(project)
      Current.user&.memberships&.exists?(project: project) || false
    end
end
