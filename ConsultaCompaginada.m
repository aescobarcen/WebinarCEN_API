let
    // 1. FUNCIÓN GetPage: Solicita una página y gestiona el código HTTP 404
    GetPage = (pageNumber as number) as list =>
        let
            // URL parametrizada por número de página
            Url = "[https://activos-tx-prod.appspot.com/api/v1/subestaciones/?page=](https://activos-tx-prod.appspot.com/api/v1/subestaciones/?page=)" & Text.From(pageNumber),
            
            // Intercepta el estado HTTP 404 para evitar un fallo fatal en Power Query
            Response = Web.Contents(Url, [ManualStatusHandling = {404}]),
            StatusCode = Value.Metadata(Response)[Response.Status]?,
            
            // Si la respuesta es 200 OK extrae los datos; si es 404 o error, devuelve una lista vacía
            Data = if StatusCode = 200 then
                        let 
                            Json = Json.Document(Binary.Buffer(Response))
                        in 
                            if Record.HasFields(Json, "results") then Json[results] else {}
                   else
                        {}
        in
            Data,

    // 2. BUCLE DINÁMICO: Consulta páginas consecutivas hasta recibir una lista vacía
    AllPagesList = List.Generate(
        () => [Page = 1, Results = GetPage(1)],                  // Inicio: Página 1
        each List.Count([Results]) > 0,                          // Condición de parada: Mientras existan datos
        each [Page = [Page] + 1, Results = GetPage([Page] + 1)], // Avance: Incrementa número de página
        each [Results]                                           // Salida: Lista de resultados por página
    ),

    // 3. CONSOLIDACIÓN: Unifica todas las páginas en una sola tabla de Power Query
    CombinedList = List.Combine(AllPagesList),
    #"Converted to Table" = Table.FromList(CombinedList, Splitter.SplitByNothing(), null, null, ExtraValues.Error)
in
    #"Converted to Table"