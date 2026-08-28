import { Controller } from "@hotwired/stimulus"

// Submits the form the moment one of its controls changes.
//
// The backlog tree is a column of status selects, and a Save button beside each
// one is exactly the friction changing status inline exists to remove. The
// partial keeps a real submit button for the no-JavaScript case, so the form
// works either way rather than only when this loads.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
