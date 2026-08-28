# The backlog tree changes status where the status is read (§7), and it does so
# by PATCHing the same update action the edit form uses. The actions differ only
# in what they answer with.
#
# Turbo matches a frame response by id, so a redirect — which is right for a
# form submission — hands the frame a whole page containing no such frame, and
# Turbo blanks the control rather than updating it. A frame request gets back
# the one control that changed; every other request gets what it always got.
module InlineStatus
  extend ActiveSupport::Concern

  private
    # Answers the request when it came from a status frame, and reports whether
    # it did — so the action falls through to its ordinary redirect or re-render
    # when it did not.
    def rendered_status_frame?(record, saved)
      return false unless turbo_frame_request?

      # A refused change snaps the control back to what is actually stored,
      # rather than leaving it sitting on a value the database rejected.
      record.reload unless saved

      render partial: "shared/status_control",
             locals: { record: record, project: @project },
             status: saved ? :ok : :unprocessable_content
      true
    end
end
