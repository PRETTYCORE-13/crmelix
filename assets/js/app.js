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

// Carrusel vertical infinito con rueda del mouse (efecto McDonald's)
const ScrollCatActive = {
  mounted() {
    this.centerActive(false)
    // Guardar posición inicial del loop_idx activo
    const list = this.el.querySelector("[data-cat-list]")
    const n = parseInt(list?.dataset.total || "1")
    const active = this.el.querySelector("[data-active='true']")
    const buttons = [...(list?.querySelectorAll("button") || [])]
    this._prevLoopIdx = active ? buttons.indexOf(active) : n

    // Rueda del mouse — throttled para evitar cambios demasiado rápidos
    this._wheelLocked = false
    this.el.addEventListener("wheel", (e) => {
      e.preventDefault()
      if (this._wheelLocked) return
      this._wheelLocked = true
      setTimeout(() => { this._wheelLocked = false }, 320)
      if (e.deltaY > 0) this.pushEvent("cat_next", {})
      else this.pushEvent("cat_prev", {})
    }, { passive: false })
    // Touch para móvil
    this._touchY = null
    this.el.addEventListener("touchstart", (e) => {
      this._touchY = e.touches[0].clientY
    }, { passive: true })
    this.el.addEventListener("touchend", (e) => {
      if (this._touchY === null) return
      const diff = this._touchY - e.changedTouches[0].clientY
      if (Math.abs(diff) > 20) {
        if (diff > 0) this.pushEvent("cat_next", {})
        else this.pushEvent("cat_prev", {})
      }
      this._touchY = null
    }, { passive: true })
  },

  updated() {
    const container = this.el
    const list = container.querySelector("[data-cat-list]")
    if (!list) return
    const n = parseInt(list.dataset.total || "1")
    const buttons = [...list.querySelectorAll("button")]
    const active = container.querySelector("[data-active='true']")
    if (!active) return

    const activeIdx = buttons.indexOf(active) // loop_idx del activo (siempre en bloque medio: n..2n-1)
    const prev = this._prevLoopIdx ?? activeIdx

    // Wrap forward: venimos del final del bloque medio, saltamos al inicio
    const wrappedForward = prev === 2 * n - 1 && activeIdx === n
    // Wrap backward: venimos del inicio del bloque medio, saltamos al final
    const wrappedBackward = prev === n && activeIdx === 2 * n - 1

    if (wrappedForward && buttons[2 * n]) {
      // Scroll suave hacia el bloque 3 (continúa hacia abajo sin salto visible)
      const nextItem = buttons[2 * n] // cat_idx=0 en bloque 3
      const targetTop = nextItem.offsetTop - (container.clientHeight / 2) + (nextItem.clientHeight / 2)
      container.scrollTo({ top: targetTop, behavior: "smooth" })
      // Después de la animación, teleport invisible al bloque medio
      setTimeout(() => {
        const resetTop = active.offsetTop - (container.clientHeight / 2) + (active.clientHeight / 2)
        container.scrollTo({ top: resetTop, behavior: "instant" })
      }, 250)
    } else if (wrappedBackward && buttons[n - 1]) {
      // Scroll suave hacia el bloque 1 (continúa hacia arriba sin salto visible)
      const prevItem = buttons[n - 1] // cat_idx=n-1 en bloque 1
      const targetTop = prevItem.offsetTop - (container.clientHeight / 2) + (prevItem.clientHeight / 2)
      container.scrollTo({ top: targetTop, behavior: "smooth" })
      // Después de la animación, teleport invisible al bloque medio
      setTimeout(() => {
        const resetTop = active.offsetTop - (container.clientHeight / 2) + (active.clientHeight / 2)
        container.scrollTo({ top: resetTop, behavior: "instant" })
      }, 250)
    } else {
      this.centerActive(true)
    }

    this._prevLoopIdx = activeIdx
  },

  centerActive(smooth = true) {
    const container = this.el
    const active = container.querySelector("[data-active='true']")
    if (!active) return
    const top = active.offsetTop - (container.clientHeight / 2) + (active.clientHeight / 2)
    container.scrollTo({ top, behavior: smooth ? "smooth" : "instant" })
  }
}

// Hook para Carrusel de tienda con auto-play y flechas
const Carrusel = {
  mounted() {
    this.idx = 0
    this.total = this.el.children.length
    this._autoplay = setInterval(() => this.next(), 4000)

    const prev = document.getElementById('carrusel-prev')
    const next = document.getElementById('carrusel-next')
    if (prev) prev.addEventListener('click', () => { this.prev(); this.resetAutoplay() })
    if (next) next.addEventListener('click', () => { this.next(); this.resetAutoplay() })

    this.el.addEventListener('scroll', () => {
      const w = this.el.clientWidth
      if (w === 0) return
      this.idx = Math.round(this.el.scrollLeft / w)
      this.updateDots()
    }, { passive: true })
  },
  next() {
    this.idx = (this.idx + 1) % this.total
    this.scrollTo(this.idx)
  },
  prev() {
    this.idx = (this.idx - 1 + this.total) % this.total
    this.scrollTo(this.idx)
  },
  scrollTo(i) {
    this.el.scrollTo({ left: i * this.el.clientWidth, behavior: 'smooth' })
    this.updateDots()
  },
  updateDots() {
    document.querySelectorAll('[id^="carrusel-dot-"]').forEach((dot, i) => {
      dot.style.opacity = i === this.idx ? '1' : '0.4'
    })
  },
  resetAutoplay() {
    clearInterval(this._autoplay)
    this._autoplay = setInterval(() => this.next(), 4000)
  },
  destroyed() {
    clearInterval(this._autoplay)
  }
}

// Hook para reordenar listas con drag-and-drop
const DragSort = {
  mounted() {
    this.draggedEl = null

    this.el.addEventListener('dragstart', (e) => {
      const item = e.target.closest('[data-drag-id]')
      if (!item) return
      this.draggedEl = item
      e.dataTransfer.effectAllowed = 'move'
      setTimeout(() => { item.style.opacity = '0.4' }, 0)
    })

    this.el.addEventListener('dragend', () => {
      if (this.draggedEl) this.draggedEl.style.opacity = '1'
      this.draggedEl = null
      this.el.querySelectorAll('[data-drag-id]').forEach(el => {
        el.style.borderTop = ''
        el.style.borderBottom = ''
      })
    })

    this.el.addEventListener('dragover', (e) => {
      e.preventDefault()
      e.dataTransfer.dropEffect = 'move'
      const item = e.target.closest('[data-drag-id]')
      if (!item || item === this.draggedEl) return
      this.el.querySelectorAll('[data-drag-id]').forEach(el => {
        el.style.borderTop = ''
        el.style.borderBottom = ''
      })
      const rect = item.getBoundingClientRect()
      const mid = rect.top + rect.height / 2
      if (e.clientY < mid) {
        item.style.borderTop = '2px solid #7c3aed'
        item.style.borderBottom = ''
      } else {
        item.style.borderBottom = '2px solid #7c3aed'
        item.style.borderTop = ''
      }
    })

    this.el.addEventListener('drop', (e) => {
      e.preventDefault()
      const targetItem = e.target.closest('[data-drag-id]')
      if (!targetItem || !this.draggedEl || targetItem === this.draggedEl) return

      const items = [...this.el.querySelectorAll('[data-drag-id]')]
      const ids = items.map(el => el.dataset.dragId)
      const draggedId = this.draggedEl.dataset.dragId
      const targetId = targetItem.dataset.dragId

      const rect = targetItem.getBoundingClientRect()
      const mid = rect.top + rect.height / 2
      const insertAfter = e.clientY >= mid

      const newIds = ids.filter(id => id !== draggedId)
      const targetIdx = newIds.indexOf(targetId)
      newIds.splice(insertAfter ? targetIdx + 1 : targetIdx, 0, draggedId)

      this.pushEvent('reorder', { ids: newIds })
    })
  }
}

// Hook que comprime imágenes en el cliente ANTES de que LiveView las suba.
// - Redimensiona a máximo 1200px en cualquier dimensión
// - Convierte a JPEG 82% de calidad
// - Actúa en capture phase para interceptar antes que el listener de LiveView
// - Si el archivo ya pesa < 250 KB, lo deja pasar sin comprimir
// - Siempre genera una preview en data URL y la guarda en input._previewDataUrl
const ImageCompressor = {
  mounted() {
    const input = this.el

    input.addEventListener('change', function handler(e) {
      // Si ya estamos comprimiendo, dejar pasar a LiveView
      if (input._compressing) return

      const file = e.target.files && e.target.files[0]
      if (!file || !file.type.startsWith('image/')) return

      // Archivos ya pequeños: generar preview y dejar pasar a LiveView
      if (file.size < 250 * 1024) {
        const reader = new FileReader()
        reader.onload = (ev) => {
          input._previewDataUrl = ev.target.result
          input.dispatchEvent(new CustomEvent('image-preview-ready', {
            detail: { url: ev.target.result }, bubbles: true
          }))
        }
        reader.readAsDataURL(file)
        return
      }

      // Detener el evento para que LiveView NO vea el archivo original
      e.stopImmediatePropagation()

      const img = new Image()
      const url = URL.createObjectURL(file)

      img.onload = function () {
        URL.revokeObjectURL(url)

        const MAX = 1200
        let w = img.naturalWidth
        let h = img.naturalHeight

        // Reducir manteniendo proporción
        if (w > MAX) { h = Math.round(h * MAX / w); w = MAX }
        if (h > MAX) { w = Math.round(w * MAX / h); h = MAX }

        const canvas = document.createElement('canvas')
        canvas.width = w
        canvas.height = h
        canvas.getContext('2d').drawImage(img, 0, 0, w, h)

        canvas.toBlob(function (blob) {
          const baseName = file.name.replace(/\.[^.]+$/, '')
          const compressed = new File([blob], baseName + '.jpg', {
            type: 'image/jpeg',
            lastModified: Date.now()
          })

          // Generar preview como data URL y notificar
          const reader = new FileReader()
          reader.onload = (ev) => {
            input._previewDataUrl = ev.target.result
            input.dispatchEvent(new CustomEvent('image-preview-ready', {
              detail: { url: ev.target.result }, bubbles: true
            }))
          }
          reader.readAsDataURL(blob)

          // Reemplazar el archivo en el input
          const dt = new DataTransfer()
          dt.items.add(compressed)

          input._compressing = true
          input.files = dt.files

          // Re-disparar change para que LiveView lo procese con el archivo comprimido
          input.dispatchEvent(new Event('change', { bubbles: true }))
          input._compressing = false
        }, 'image/jpeg', 0.82)
      }

      img.onerror = function () {
        URL.revokeObjectURL(url)
        // Si falla la compresión, dejar el archivo original pasar
        input._compressing = true
        input.dispatchEvent(new Event('change', { bubbles: true }))
        input._compressing = false
      }

      img.src = url
    }, true) // capture = true: intercepta antes que el listener de LiveView
  }
}

// Hook que muestra la preview de la imagen seleccionada en el input correspondiente.
// Escucha el evento 'image-preview-ready' disparado por ImageCompressor
// y en mounted() verifica si ya hay un data URL guardado en el input.
const ImagePreview = {
  mounted() {
    const inputId = this.el.dataset.inputId
    const input = document.getElementById(inputId)

    // Fast path: la compresión ya terminó antes que el hook se montara
    if (input && input._previewDataUrl) {
      this.el.src = input._previewDataUrl
      this.el.classList.remove('hidden')
    }

    // Slow path: esperar el evento (compresión aún en curso cuando se montó el hook)
    this._previewHandler = (e) => {
      if (e.target && e.target.id === inputId) {
        this.el.src = e.detail.url
        this.el.classList.remove('hidden')
      }
    }
    document.addEventListener('image-preview-ready', this._previewHandler)
  },
  destroyed() {
    if (this._previewHandler) {
      document.removeEventListener('image-preview-ready', this._previewHandler)
    }
  }
}

// Hook para persistir estado de sincronización entre navegaciones.
// Usa window (memoria) → se limpia al refrescar el navegador pero sobrevive
// la navegación LiveView (push_navigate no recarga el JS).
const TiendaSync = {
  mounted() {}
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: isLocalhost ? null : 5000,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, LocationMap, NavigateAfterFlash, AutoFlash, ScrollCatActive, Carrusel, DragSort, TiendaSync, ImageCompressor, ImagePreview},
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

