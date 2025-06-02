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
      this.mapTarget.classList.remove("d-none");
      this.listTarget.classList.add("d-none");
      this.buttonTarget.textContent = "Show List";
    } else {
      this.mapTarget.classList.add("d-none");
      this.listTarget.classList.remove("d-none");
      this.buttonTarget.textContent = "Show Map";
    }
  }
}
