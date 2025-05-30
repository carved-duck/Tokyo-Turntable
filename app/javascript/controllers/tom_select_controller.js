import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

export default class extends Controller {
  static values = { options: Object }

  connect() {
    this.tomSelect = new TomSelect(
      this.element,
      this.optionsValue
    );

    this.tomSelect.onItemAdd = (value, $item) => { this.clearTextbox(); }
  }

  clearInput(e) {
    console.log(e, "trigger")
  }
}
