// app/javascript/controllers/datepicker_controller.js

import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr";
// REMOVE THIS LINE: import "flatpickr/dist/flatpickr.min.css";

export default class extends Controller {
  flatpickrInstance = null;

  connect() {
    // Destroy existing flatpickr instance if it exists
    if (this.flatpickrInstance) {
      this.flatpickrInstance.destroy()
    }

    this.flatpickrInstance = flatpickr(this.element, {
      altInput: true,
      altFormat: "F j, Y",
      dateFormat: "Y-m-d",
      // Add other Flatpickr options as needed
    });
  }

  disconnect() {
    // Flatpickr cleanup - console.log removed for production
    if (this.flatpickrInstance) {
      this.flatpickrInstance.destroy()
    }
  }
}
