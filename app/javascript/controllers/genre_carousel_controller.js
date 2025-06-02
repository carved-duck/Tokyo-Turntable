import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="genre-carousel"
export default class extends Controller {
  static targets = ["carousel"]

  connect() {
    console.log("Genre carousel connected")
  }

  select(event) {
    const button = event.currentTarget
    const genreName = button.dataset.genreCarouselGenreName
    console.log("Selected genre:", genreName)

    // Optional: Add selected styling or send request
    this.clearSelected()
    button.classList.add("bg-blue-500", "text-white")
  }

  clearSelected() {
    this.carouselTarget.querySelectorAll("button").forEach((btn) => {
      btn.classList.remove("bg-blue-500", "text-white")
      btn.classList.add("bg-gray-200")
    })
  }
}
