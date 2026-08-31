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