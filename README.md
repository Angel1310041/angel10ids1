# Gestión de Clientes - Aplicación Flutter

Aplicación móvil desarrollada en **Flutter** con arquitectura reactiva, integración con **Firebase**, consumo de **APIs REST (PokéAPI)**, gestión de **contactos del dispositivo**, escáner de **código QR y códigos de barras**, y almacenamiento local persistente con **SharedPreferences**.

---

## 🚀 Características Principales

1. **Autenticación y Persistencia (`Firebase Auth` & `SharedPreferences`)**:
   - Registro e Inicio de sesión con correo electrónico y contraseña.
   - Guardado automático de la sesión local con `SharedPreferences`.
   - Recuperación automática de sesión activa al reiniciar la app.

2. **Gestión de Clientes (`Cloud Firestore`)**:
   - CRUD Completo (Crear, Leer, Actualizar, Eliminar) en tiempo real.
   - Clasificación personalizada por cliente.
   - Filtro dinámico de clientes por categoría en la interfaz.

3. **Gestión de Clasificaciones**:
   - CRUD Completo para crear categorías de clientes (ej. VIP, Frecuente, Potencial).
   - Asignación múltiple interactiva de clientes desde las clasificaciones.
   - Actualización en cascada al modificar o eliminar categorías.

4. **APIs REST Pokémon (`PokéAPI`)**:
   - Peticiones HTTP a `https://pokeapi.co/api/v2/pokemon`.
   - Listado con imágenes en alta calidad (Official Artwork) e ID.
   - Vista de detalle con tipos, altura, peso, habilidades y estadísticas base con barras de progreso.

5. **Contactos del Dispositivo & Integración con WhatsApp**:
   - Solicitud de permisos en tiempo de ejecución.
   - Lectura de lista de contactos del dispositivo.
   - Botón directo para abrir WhatsApp con el mensaje predeterminado de bienvenida a la UTTEC.

6. **Escáner QR y Código de Barras (`mobile_scanner`)**:
   - Uso de la cámara del dispositivo con control de flash y cambio de cámara.
   - Apertura automática en el navegador si el QR contiene la URL oficial de la UTTEC o cualquier enlace web.
   - Lectura de códigos de barras (credenciales, productos, EAN-13, CODE-128, etc.) mostrando formato y valor.

---

## 🛠️ Requisitos e Instalación

1. **Clonar el repositorio**:
   ```bash
   git clone https://github.com/tu-usuario/angel10ids1.git
   cd angel10ids1
   ```

2. **Instalar dependencias**:
   ```bash
   flutter pub get
   ```

3. **Ejecutar la aplicación**:
   ```bash
   flutter run
   ```

4. **Compilar APK de producción**:
   ```bash
   flutter build apk --release
   ```

---

## 📄 Licencia

Este proyecto está bajo la Licencia **MIT** - consulta el archivo [LICENSE](LICENSE) para más detalles.
