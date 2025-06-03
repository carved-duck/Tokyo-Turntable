import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["map", "list", "button"];

  connect() {
    // Show list first, hide map
    this.showingMap = false;
    this.mapTarget.classList.add("d-none");
    this.listTarget.classList.remove("d-none");
    this.buttonTarget.textContent = "Show Map";
  }

  toggle() {
    this.showingMap = !this.showingMap;

    if (this.showingMap) {
      // show the map, hide the list
      this.mapTarget.classList.remove("d-none");
      this.listTarget.classList.add("d-none");
      this.buttonTarget.textContent = "Show List";
       // tell Mapbox to recalculate its size now that the container is visible
      window.dispatchEvent(new Event("resize"));
    } else {
      // show the list, hide the map
      this.mapTarget.classList.add("d-none");
      this.listTarget.classList.remove("d-none");
      this.buttonTarget.textContent = "Show Map";
    }
  }
}
