// app/javascript/controllers/mapbox_controller.js

import { Controller } from "@hotwired/stimulus"
import mapboxgl from 'mapbox-gl'
import { Offcanvas } from "bootstrap" // Assuming this is used elsewhere in your app

export default class extends Controller {
  static values = { apiKey: String, markers: Array }

  // Declare map as a class property, initialized to null
  map = null;

  connect() {
    console.log("Mapbox Stimulus controller connected!"); // Added for debugging

    // Defensive check: If a map instance already exists on this element, destroy it first.
    if (this.map) { // Check the class property where we store the map instance
      console.log("Destroying existing Mapbox map instance.");
      this.map.remove(); // Mapbox GL JS uses .remove() to destroy the map
      this.map = null; // Clear the reference
    }

    mapboxgl.accessToken = this.apiKeyValue
    this.map = new mapboxgl.Map({
      container: this.element, // this.element is the div with data-controller="map"
      style: "mapbox://styles/mapbox/streets-v12",
    });

    // filter out any null coords, but need to check later...
    const valid = this.markersValue.filter(m => m.lng != null && m.lat != null)
    // add each gig-marker
    valid.forEach(m => this._addMarker(m))

    if (valid.length > 0) {
      this._fitMapToMarkers(valid) // Pass valid markers to the method
    } else {
      // no markers then we show Tokyo
      this.map.setCenter([139.6917, 35.6895])
      this.map.setZoom(10)
    }

    console.log("Mapbox map initialized:", this.map); // Added for debugging
  }

  // ADD THIS DISCONNECT METHOD
  disconnect() {
    console.log("Mapbox Stimulus controller disconnected."); // Added for debugging
    if (this.map) {
      this.map.remove(); // Crucial: destroy the map instance when the controller disconnects
      this.map = null; // Clear the reference
    }
  }

  _addMarker(marker) {
    const defaultPin = new mapboxgl.Marker()
      .setLngLat([marker.lng, marker.lat])
      .addTo(this.map)
      const popup = new mapboxgl.Popup({
        offset: [0, -30],
        closeButton: false,
        closeOnClick: false,
        className: "label-only-popup"
      })
      .setLngLat([marker.lng, marker.lat])
      .setText(marker.neighborhood)
      .addTo(this.map)

    defaultPin.getElement().addEventListener("click", () => {
      const tpl = document.getElementById(`gig-sheet-${marker.id}`)
      document.getElementById("gigDetailsContent").innerHTML = tpl.innerHTML
      new Offcanvas(document.getElementById("gigDetailsSheet")).show()
    })
  }

  // Modified _fitMapToMarkers to accept markers as an argument
  _fitMapToMarkers(markers) {
    const bounds = new mapboxgl.LngLatBounds()
    markers.forEach(m => bounds.extend([m.lng, m.lat]))
    this.map.fitBounds(bounds, { padding: 70, maxZoom: 15, duration: 0 })
  }
}
