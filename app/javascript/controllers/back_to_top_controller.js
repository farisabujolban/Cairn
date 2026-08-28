import { Controller } from "@hotwired/stimulus"

// §7's back-to-top button. The backlog tree is the screen that earns it: a
// project with twenty epics is a long page, and everything that acts on the
// project sits at the top of it.
//
// Hidden with the `hidden` attribute rather than with opacity, so a button
// nobody can see is not a tab stop either.
export default class extends Controller {
  // 200px is roughly the point where the project's own controls — Edit,
  // Archive, Delete and the section nav — have scrolled off the top, which is
  // when a way back starts earning its place.
  //
  // It was 400px, which was too high to ever fire. A backlog of eleven epics is
  // about 1100px tall, so on any normal window it scrolls by 0-220px and never
  // crossed it: the button was effectively dead code on real content.
  static values = { threshold: { type: Number, default: 200 } }

  connect() {
    // Bound once and kept, so disconnect() removes the same function it added.
    // A fresh bind would leave the old listener attached to a dead controller
    // on every Turbo navigation.
    this.onScroll = this.onScroll.bind(this)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.onScroll()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }

  onScroll() {
    this.element.hidden = window.scrollY < this.thresholdValue
  }

  scrollToTop() {
    // §7 names this scroll specifically as something that must honour
    // prefers-reduced-motion. The global CSS rule cannot reach it: a behavior
    // passed to scrollTo overrides CSS scroll-behavior, so the media query has
    // to be asked here.
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches

    window.scrollTo({ top: 0, behavior: reduced ? "auto" : "smooth" })
  }
}
