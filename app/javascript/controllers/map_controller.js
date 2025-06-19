// app/javascript/controllers/mapbox_controller.js

import { Controller } from "@hotwired/stimulus"
import mapboxgl from 'mapbox-gl'
import { Offcanvas } from "bootstrap" // Assuming this is used elsewhere in your app

export default class extends Controller {
  static values = { apiKey: String, markers: Array }

  // Declare map as a class property, initialized to null
  map = null;

  connect() {
    mapboxgl.accessToken = this.apiKeyValue

    // Destroy existing map instance if it exists
    if (this.map) {
      this.map.remove()
    }

    this.map = new mapboxgl.Map({
      container: this.element,
      style: "mapbox://styles/mapbox/streets-v10"
    })

    this.#addMarkersToMap()
    this.#fitMapToMarkers()
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
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

  #addMarkersToMap() {
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
  }

  #fitMapToMarkers() {
    this.#addMarkersToMap()
  }
}
