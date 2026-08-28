import { Controller } from "@hotwired/stimulus"

// One button that shows or hides one region, with aria-expanded kept in step.
//
// Deliberately generic: the backlog tree is a long list of these and nothing
// about the behaviour is specific to epics or stories. The alternative was
// <details>/<summary>, which is free and accessible but puts every control in
// the row inside the summary — where clicking a status select toggles the
// branch instead of opening the select.
//
// Nesting works because Stimulus scopes targets to the nearest controller
// element of the same identifier, so an epic's controller never claims a
// story's button.
export default class extends Controller {
  static targets = [ "button", "region" ]

  toggle() {
    const expanded = this.buttonTarget.getAttribute("aria-expanded") === "true"

    this.buttonTarget.setAttribute("aria-expanded", String(!expanded))
    // The hidden attribute rather than a class: it is what assistive technology
    // reads, and it does not depend on a stylesheet having loaded.
    this.regionTarget.hidden = expanded
  }
}
