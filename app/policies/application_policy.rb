# The §4 permission matrix, written down once.
#
# Every permission in this app is a question about one role in one project, so
# the resolution of "which role does this user hold over this record" lives here
# and nowhere else. Subclasses override only the rows where their model departs
# from the work-item defaults below.
class ApplicationPolicy
  # The matrix columns that carry privilege, named rather than derived from
  # Membership::ROLES by position: "the first three roles" would not survive a
  # fifth role being added between them.
  CONTRIBUTOR_ROLES = %w[ owner admin member ].freeze
  ADMINISTRATOR_ROLES = %w[ owner admin ].freeze

  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  # Matrix row 1 — view project, epics, stories, tasks. Every role, no exceptions.
  def index? = member?
  def show? = member?

  # Matrix rows 2 and 3 — create / edit / delete epics, stories, tasks and
  # milestones. Ordinary project work, so it stops at member: a viewer reads
  # everything and changes nothing.
  def create? = contributor?
  def update? = contributor?
  def destroy? = contributor?

  # The form screens answer exactly as the submissions they lead to, so nobody
  # is shown a form whose save would come back 403.
  def new? = create?
  def edit? = update?

  # Indexes filter in the query, never in the view (§4). Each subclass says how
  # its model reaches a project the user is a member of.
  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    # Raising beats returning the unfiltered scope: a subclass that forgets this
    # must break the build, not quietly list every project's rows.
    def resolve
      raise NoMethodError, "#{self.class} must define #resolve"
    end
  end

  private
    # Every record in this app sits in exactly one project — either by being
    # one, or by reaching one through containment. Nothing else is consulted.
    def project
      record.is_a?(Project) ? record : record.try(:project)
    end

    # nil for a non-member, which is what collapses every predicate above to
    # false at once instead of each needing its own non-member branch.
    def role
      return @role if defined?(@role)

      # Asked of the user rather than queried here: the backlog tree builds one
      # policy per row, so each instance's own memoization would still be a
      # query per row. User#membership_in caches across all of them.
      @role = user&.membership_in(project)&.role
    end

    def member? = role.present?
    def contributor? = role.in?(CONTRIBUTOR_ROLES)
    def administrator? = role.in?(ADMINISTRATOR_ROLES)
    def owner? = role == "owner"
end
