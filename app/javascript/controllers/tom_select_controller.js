import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

// Connects to data-controller="tom-select"
export default class extends Controller {
  connect() {
    new TomSelect(this.element, {
      plugins: ['remove_button'],
      create: true,
      maxItems: 3,
      render: {
        option: function(data, escape) {
          return `<div><i class="fa-solid fa-music me-2"></i> ${escape(data.text)}</div>`;
        },
        item: function(data, escape) {
          return `<div><i class="fa-solid fa-music me-1"></i> ${escape(data.text)}</div>`;
        }
      },
      valueField: "value",
      labelField: "text",
      searchField: "text",
      load: function(query, callback) {
        if (!query.length) return callback();
        fetch(`/genres?q=${encodeURIComponent(query)}`)
          .then(response => response.json())
          .then(json => {
            callback(json);
          }).catch(() => {
            callback();
          });
      },
      placeholder: "Select or add genres",
    })
  };}
