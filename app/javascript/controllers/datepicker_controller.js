// app/javascript/controllers/datepicker_controller.js

import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr";
// REMOVE THIS LINE: import "flatpickr/dist/flatpickr.min.css";

export default class extends Controller {
  flatpickrInstance = null;

  connect() {
    console.log("flatpickr Stimulus controller connected!");

    if (this.element._flatpickr) {
      console.log("Destroying existing flatpickr instance.");
      this.element._flatpickr.destroy();
    }

    this.flatpickrInstance = flatpickr(this.element, {
      altInput: true,
      altFormat: "F j, Y",
      dateFormat: "Y-m-d",
      // Add other Flatpickr options as needed
    });

    console.log("Flatpickr initialized:", this.flatpickrInstance);
  }

  disconnect() {
    console.log("flatpickr Stimulus controller disconnected.");
    if (this.flatpickrInstance) {
      this.flatpickrInstance.destroy();
      this.flatpickrInstance = null;
    }
  }
}
