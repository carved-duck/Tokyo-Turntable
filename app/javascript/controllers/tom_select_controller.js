import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

export default class extends Controller {
  static values = { options: Object }

  connect() {
    this.tomSelect = new TomSelect(
      this.element,
      {
        maxItems: 3,
        maxOptions: 3,
        create: false,
        plugins: ['remove_button'],
        openOnFocus: false,
        onItemAdd: function() { this.setTextboxValue("") }
      }
    );

    this.tomSelect.onItemAdd = (value, $item) => { this.clearTextbox(); }
  }

  clearInput(e) {
    console.log(e, "trigger")
  }
}
