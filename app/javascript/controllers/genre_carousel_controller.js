import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="genre-carousel"
export default class extends Controller {
  static targets = ["genre"]

  connect() {
    // Genre carousel connected - console.log removed for production
  }

  selectGenre(event) {
    const genreName = event.currentTarget.dataset.genre
    // Selected genre logic - console.log removed for production

    // Remove active class from all genres
    this.genreTargets.forEach(genre => {
      genre.classList.remove("active")
    })

    // Add active class to clicked genre
    event.currentTarget.classList.add("active")

    // Dispatch custom event with selected genre
    this.dispatch("genreSelected", { detail: { genre: genreName } })
  }
}
