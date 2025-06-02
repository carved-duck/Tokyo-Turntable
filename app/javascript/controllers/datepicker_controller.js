// app/javascript/controllers/datepicker_controller.js

import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"; // You need to import this to use new flatpickr()

export default class extends Controller {
  connect() {
    console.log("flatpickr")
    flatpickr(this.element)
  }
}
