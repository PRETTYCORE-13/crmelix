// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/prettycore"
import topbar from "../vendor/topbar"

// ============================================================
// Google Maps API - Configuración
// ============================================================
// IMPORTANTE: Reemplaza 'TU_API_KEY_AQUI' con tu API Key de Google Maps
// Obtén una en: https://console.cloud.google.com/apis/credentials
const GOOGLE_MAPS_API_KEY = 'AIzaSyCoccXAGyYsvt46PKXYFAS2vPl2SVHU7yE';

let googleMapsLoaded = false;
let googleMapsLoadingPromise = null;

function loadGoogleMaps() {
  if (googleMapsLoaded && window.google && window.google.maps) {
    return Promise.resolve();
  }

  if (googleMapsLoadingPromise) {
    return googleMapsLoadingPromise;
  }

  googleMapsLoadingPromise = new Promise((resolve, reject) => {
    if (window.google && window.google.maps) {
      googleMapsLoaded = true;
      resolve();
      return;
    }

    // Callback global para cuando Google Maps termine de cargar
    window.initGoogleMapsCallback = () => {
      googleMapsLoaded = true;
      resolve();
    };

    const script = document.createElement('script');
    script.src = `https://maps.googleapis.com/maps/api/js?key=${GOOGLE_MAPS_API_KEY}&callback=initGoogleMapsCallback&loading=async`;
    script.async = true;
    script.defer = true;
    script.onerror = () => {
      reject(new Error('Error al cargar Google Maps'));
    };
    document.head.appendChild(script);
  });

  return googleMapsLoadingPromise;
}

// Hook para Mapa Interactivo con Google Maps
const LocationMap = {
  mounted() {
    this.initializeMap();
  },

  async initializeMap() {
    try {
      await loadGoogleMaps();
      requestAnimationFrame(() => {
        this.initMap();
      });
    } catch (error) {
      console.error('Error cargando Google Maps:', error);
      this.showError();
    }
  },

  initMap() {
    if (!window.google || !window.google.maps) {
      console.error('Google Maps no está disponible');
      this.showError();
      return;
    }

    const lat = parseFloat(this.el.dataset.lat) || 19.4326;
    const lng = parseFloat(this.el.dataset.lng) || -99.1332;

    try {
      // Inicializar mapa de Google
      this.map = new google.maps.Map(this.el, {
        center: { lat, lng },
        zoom: 15,
        mapTypeId: 'roadmap',
        mapTypeControl: true,
        streetViewControl: false,
        fullscreenControl: true,
        zoomControl: true
      });

      // Agregar marcador arrastrable
      this.marker = new google.maps.Marker({
        position: { lat, lng },
        map: this.map,
        draggable: true,
        title: 'Arrastre para mover la ubicación'
      });

      // Evento cuando se arrastra el marcador
      this.marker.addListener('dragend', () => {
        const position = this.marker.getPosition();
        this.updateCoordinates(position.lat(), position.lng());
      });

      // Evento de clic en el mapa
      this.map.addListener('click', (e) => {
        const lat = e.latLng.lat();
        const lng = e.latLng.lng();
        this.marker.setPosition({ lat, lng });
        this.updateCoordinates(lat, lng);
      });

    } catch (error) {
      console.error('Error al inicializar Google Maps:', error);
      this.showError();
    }
  },

  showError() {
    this.el.innerHTML = `
      <div style="display: flex; align-items: center; justify-content: center; height: 100%; flex-direction: column; background: #f3f4f6; border-radius: 8px;">
        <p style="color: #dc2626; margin-bottom: 8px;">Error al cargar Google Maps</p>
        <p style="color: #6b7280; font-size: 12px; margin-bottom: 12px;">Verifica tu API Key</p>
        <button onclick="location.reload()" style="padding: 8px 16px; background: #3b82f6; color: white; border: none; border-radius: 4px; cursor: pointer;">
          Recargar página
        </button>
      </div>
    `;
  },

  updateCoordinates(lat, lng) {
    const index = this.el.dataset.index || "0";
    const mapXInput = document.querySelector(`input[name="cliente_form[direcciones][${index}][map_x]"]`);
    const mapYInput = document.querySelector(`input[name="cliente_form[direcciones][${index}][map_y]"]`);

    if (mapXInput) mapXInput.value = lng.toFixed(6);
    if (mapYInput) mapYInput.value = lat.toFixed(6);

    this.pushEvent("update_coordinates", { lat: lat, lng: lng, index: index });
  },

  updated() {
    if (!this.map || !this.marker) return;

    const lat = parseFloat(this.el.dataset.lat) || 19.4326;
    const lng = parseFloat(this.el.dataset.lng) || -99.1332;

    this.marker.setPosition({ lat, lng });
    this.map.setCenter({ lat, lng });
  },

  destroyed() {
    if (this.marker) {
      this.marker.setMap(null);
      this.marker = null;
    }
    this.map = null;
  }
};

// Hook para navegación retrasada después de mostrar flash
const NavigateAfterFlash = {
  mounted() {
    this.handleEvent("navigate-after-flash", ({to, delay}) => {
      setTimeout(() => {
        window.location.href = to;
      }, delay);
    });
  }
};

// Hook para auto-cerrar flash después de 3 segundos
const AutoFlash = {
  mounted() {
    this.timer = setTimeout(() => {
      this.el.style.transition = "opacity 0.4s ease, transform 0.4s ease"
      this.el.style.opacity = "0"
      this.el.style.transform = "translateX(20px)"
      setTimeout(() => {
        this.el.click()
      }, 400)
    }, 3000)
  },
  destroyed() {
    clearTimeout(this.timer)
  }
}

const isLocalhost = window.location.hostname === "localhost" || window.location.hostname.includes("localhost");

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: isLocalhost ? null : 5000,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, LocationMap, NavigateAfterFlash, AutoFlash},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

