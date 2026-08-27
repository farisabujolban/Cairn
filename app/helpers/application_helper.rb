module ApplicationHelper
  # Every back link is the same shape, so the arrow extends on hover everywhere.
  # The arrow is decoration: screen readers hear the label alone.
  def back_link_to(label, url)
    link_to url, class: "back-link inline-flex items-center gap-1 text-sm text-slate-600 transition-colors hover:text-slate-900 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2" do
      safe_join([ tag.span("←", class: "back-link__arrow", aria: { hidden: true }), label ])
    end
  end
end
