# Integración de API BDATX con Power BI

Este repositorio contiene la documentación, ejemplos de consulta y scripts en lenguaje M para conectar Power BI Desktop con la API de la plataforma BDATX del Coordinador Eléctrico Nacional, permitiendo una extracción automatizada y paginada de activos del Sistema Eléctrico Nacional.

---

## Recursos y Swagger

* **Documentación API (Swagger):** [https://activos-tx-prod.appspot.com/](https://activos-tx-prod.appspot.com/)
* **Base URL:** `https://activos-tx-prod.appspot.com/api/v1/`

---

## Consultas Utilizadas en el Ejemplo

### 1. Endpoints Principales

| Instalación | Slug | Endpoint GET |
| :--- | :--- | :--- |
| **Subestaciones** | `subestaciones` | `https://activos-tx-prod.appspot.com/api/v1/subestaciones/` |
| **Paños** | `panos` | `https://activos-tx-prod.appspot.com/api/v1/panos/` |
| **Desconectadores** | `desconectadores` | `https://activos-tx-prod.appspot.com/api/v1/desconectadores/` |

---

### 2. "Hacks" y Parámetros de Filtrado Directo (URL Params)

Para evitar descargar la base de datos completa y optimizar el tiempo de respuesta, se pueden utilizar los siguientes filtros directamente en la URL:

**Por ID de Instalación:**
  ```http
  GET /api/v1/subestaciones/{id}

```


**Filtro por Nombre Exacto:**
 ```http

  GET /api/v1/subestaciones/?name=S/E CUMBRE

 ``` 


**Filtro por Coincidencia Parcial en Nombre (icontains):**
```http
GET /api/v1/subestaciones/?name__icontains=CUMBRE

```


**Filtro por Empresa Propietaria:**
```http
GET /api/v1/panos/?propietario__icontains=TRANSMISORA

```

---

## Resumen del Caso Práctico

### Problema de Negocio

Tradicionalmente, la obtención de datos sobre la infraestructura del sistema eléctrico requiere descargas manuales periódicas en formato Excel. Este proceso presenta varias limitantes:

* Alto riesgo de desfase de datos (información estática).
* Trabajo repetitivo e ineficiente para auditorías o monitoreo continuo.
* Dependencia de la intervención humana para actualizar reportes.

### Solución Desarrollada

Se implementó un flujo automatizado en Power BI que consume directamente la API REST. Mediante un script en lenguaje M, se resuelve el límite de paginación de la API y se consolida el inventario completo de activos en una estructura tabular relacional de actualización directa.

---

### Mapeo de Datos (JSON a Modelo Relacional)

La respuesta de la API entrega estructuras JSON con registros anidados. Power Query se encarga de desempaquetar y transformar estas claves en columnas de reporte estándar:

```json
{
  "count": 1,
  "results": [
    {
      "id": 4,
      "name": "DES S/E ILLAPA J1-1",
      "status": "EN_OPERACION",
      "propietario": {
        "id": "P_574",
        "name": "DIEGO DE ALMAGRO TRANSMISORA DE ENERGÍA S.A."
      },
      "nodo": {
        "id": 8,
        "name": "PA S/E ILLAPA J1"
      },
      "datasheet": {
        "corrienteCortocircuito": {
          "magnitud": 40,
          "unidad": "kA"
        }
      }
    }
  ]
}

```

**Tabla Homóloga Resultante en Power BI:**

| ID | Nombre Subestación / Activo | Estado Operativo | Propietario | Corto Circuito |
| --- | --- | --- | --- | --- |
| **4** | DES S/E ILLAPA J1-1 | `EN_OPERACION` | DIEGO DE ALMAGRO TRANSMISORA... | **40 kA** |

---

## Código Genérico en M (Paginación Dinámica)

Este script en lenguaje M implementa una función parametrizada con control de excepciones HTTP. Utiliza `ManualStatusHandling = {404}` para interceptar el fin de datos sin interrumpir la ejecución en Power BI, e itera dinámicamente mediante `List.Generate`.

```powerquery
let
    // 1. Función parametrizada con captura del código HTTP 404
    GetPage = (pageNumber as number) as list =>
        let
            // Endpoint parametrizado por número de página
            Url = "https://URL_DE_TU_API/endpoint/?page=" & Text.From(pageNumber),
            
            // Intercepta el código 404 para evitar que Power BI aborte la consulta
            Response = Web.Contents(Url, [ManualStatusHandling = {404}]),
            StatusCode = Value.Metadata(Response)[Response.Status]?,
            
            // Si la llamada es exitosa (200), extrae los resultados; si no (404), retorna lista vacía
            Data = if StatusCode = 200 then
                        Json.Document(Binary.Buffer(Response))[results]
                   else
                        {}
        in
            Data,

    // 2. Bucle dinámico que itera hasta recibir una lista vacía
    AllPagesList = List.Generate(
        () => [Page = 1, Results = GetPage(1)],                  // Inicio en página 1
        each List.Count([Results]) > 0,                          // Condición de parada (Count = 0)
        each [Page = [Page] + 1, Results = GetPage([Page] + 1)], // Incremento
        each [Results]                                           // Selección de salida
    ),

    // 3. Consolidación de páginas y conversión a estructura tabular
    CombinedList = List.Combine(AllPagesList),
    #"Converted to Table" = Table.FromList(CombinedList, Splitter.SplitByNothing(), null, null, ExtraValues.Error)
in
    #"Converted to Table"

```

---

## Paso a Paso de Ejecución en Power BI

1. **Power Query:**
* Crear una **Consulta en blanco** en Power BI Desktop.
* Abrir el **Editor avanzado** y pegar el script M genérico ajustando la URL del endpoint deseado.
* Expandir los registros de la columna resultante para extraer los campos requeridos (`name`, `status`, `propietario`, etc.).
* Seleccionar **Cerrar y aplicar**.


2. **Modelado y Visualización:**
* Establecer las relaciones `1:*` entre la tabla de empresas y los activos del sistema.
* Crear medidas de conteo mediante DAX:
```dax
Total Activos = COUNTROWS(TablaActivos)

```

* Configurar tarjetas KPI y tablas de control para visualizar el inventario consolidado en tiempo real.
