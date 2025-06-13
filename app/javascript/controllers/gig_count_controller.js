import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="genre-filter"
export default class extends Controller {
  static targets = ["dateInput", "genreSelect", "totalGigs"]
  connect() {
    // Remove console.log for production
  }

  getGigCount() {
    const genres = Array.from(this.genreSelectTarget.nextElementSibling.querySelectorAll(".ts-control .item")).map(el=>el.getAttribute("data-value"))
    const date = this.dateInputTarget.value

    const url = `${location.href}?date=${date}&genres=${genres.join(", ")}`

    fetch(url,{
      method: "GET", // Could be dynamic with Stimulus values
      headers: { "Accept": "application/json" }
    }).then(response=>response.json())
      .then(data=>{
        this.totalGigsTarget.innerText = `Shows found: ${data.count}`
      })
  }

}
