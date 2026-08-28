module ApplicationHelper
  # The delete confirmation, per §13 phase 5: it names the cascade instead of
  # asking "are you sure?". Deleting a project reaches four levels down plus the
  # roster, and the person deciding has one screen of that in front of them at
  # most.
  #
  # Each level is pluralized on its own count rather than the sentence being
  # pluralized as a whole, so one epic and four stories does not read "1 epics".
  def deletion_warning(project)
    contents = project.contents
    ending = "This cannot be undone."
    return "Delete #{project.name}? #{ending}" if contents.empty?

    destroyed = contents.map { |level, count| pluralize(count, level) }.to_sentence
    "Delete #{project.name}? This permanently destroys #{destroyed}. #{ending}"
  end

  # One input style for every form in the app, so the focus ring §7 requires is
  # not something each form has to remember separately — and so an invalid field
  # reads as invalid to someone who cannot hear aria-invalid.
  def field_classes(invalid: false)
    class_names(
      "block w-full rounded-md border px-3 py-2 transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-900",
      "border-red-300 bg-red-50" => invalid,
      "border-slate-300 bg-white" => !invalid)
  end

  # Every back link is the same shape, so the arrow extends on hover everywhere.
  # The arrow is decoration: screen readers hear the label alone.
  def back_link_to(label, url)
    link_to url, class: "back-link inline-flex items-center gap-1 text-sm text-slate-600 transition-colors hover:text-slate-900 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2" do
      safe_join([ tag.span("←", class: "back-link__arrow", aria: { hidden: true }), label ])
    end
  end
end
