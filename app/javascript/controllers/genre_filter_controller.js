import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="genre-filter"
export default class extends Controller {
  connect() {
    console.log("hi")
  }
}
