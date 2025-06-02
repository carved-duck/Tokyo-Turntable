import { Controller } from "@hotwired/stimulus"
import mapboxgl from 'mapbox-gl'
import { Offcanvas } from "bootstrap"

export default class extends Controller {
  static values = { apiKey: String, markers: Array }

  connect() {
    mapboxgl.accessToken = this.apiKeyValue
    this.map = new mapboxgl.Map({
      container: this.element,
      style: "mapbox://styles/mapbox/streets-v12",
    });

    // filter out any null coords, but need to check later...
    const valid = this.markersValue.filter(m => m.lng != null && m.lat != null)
    // add each gig-marker
    valid.forEach(m => this._addMarker(m))

    if (valid.length > 0) {
      this._fitMapToMarkers(valid)
    } else {
      // no markers then we show Tokyo
      this.map.setCenter([139.6917, 35.6895])
      this.map.setZoom(10)
    }
  }

  _addMarker(marker) {
    const el = document.createElement("div")
    el.innerHTML = marker.marker_html
    new mapboxgl.Marker(el)
      .setLngLat([marker.lng, marker.lat])
      .addTo(this.map)
      .getElement()
      .addEventListener("click", () => {
        const tpl = document.getElementById(`gig-sheet-${marker.id}`)
        document.getElementById("gigDetailsContent").innerHTML = tpl.innerHTML
        new Offcanvas(document.getElementById("gigDetailsSheet")).show()
      })
  }

  _fitMapToMarkers() {
    const bounds = new mapboxgl.LngLatBounds()
    this.markersValue.forEach(m => bounds.extend([m.lng, m.lat]))
    this.map.fitBounds(bounds, { padding: 70, maxZoom: 15, duration: 0 })
  }
}
