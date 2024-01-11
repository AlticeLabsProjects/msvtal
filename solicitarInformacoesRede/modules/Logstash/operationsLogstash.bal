import ballerina/log;
import ballerina/time;
import solicitarInformacoesRede.NetQ;

# Function para registrar log de inicio do serviço ao logstash.
#
# + inicialPayload - xml enviado pelo ambiente;
# + return - possivel erro em alguma das etapas do logstash.
public isolated function initialReqLogstash(xml inicialPayload) returns json|error {
    json transformPayload = check NetQ:getDataFromNETQXml(inicialPayload);

    json adaptPayload = {
        "correlationId": check transformPayload.idNetq,
        "operation": check transformPayload.operation
    };

    // Create and send initial log to Logstash 
    json|error requestString = transformRequestLogstash(adaptPayload,
    null,inicialPayload,"START");
    boolean _ = check sendRequestLogstash(check requestString);

    return adaptPayload;
}

# Function para registrar log de fim do serviço ao logstash.
#
# + inicialPayload - xml enviado pelo ambiente;
# + response - json|xml resultado do serviço principal;
# + totalTime - int tempo total da requisição;
# + return - possivel erro em alguma das etapas do logstash.
public isolated function finalReqLogstash(json inicialPayload, json|xml|error response, int totalTime) returns error? {

    string statusCode = "200";    
    json|xml|string|error integrationFinalResponse;
    if (response is ()) {
        integrationFinalResponse = "Nenhum valor de retorno.";
    } else {
        if (response is error) {
            statusCode = "500";
        }
        integrationFinalResponse = response;
    }

    json totalTimeJson = {
        "responseTime": totalTime,
        "status": statusCode
    };

    json requestLog = check inicialPayload.mergeJson(totalTimeJson);

    // Create and send final log to Logstash
    json|error responseString = transformRequestLogstash(requestLog,
        integrationFinalResponse, null, "END");
    boolean _ = check sendRequestLogstash(check responseString);
}

# Function para registrar log de integração do serviço ao logstash.
#
# + address - string com endereço a ser chamado;
# + request - json|xml request do serviço principal;
# + response - json|xml resultado inicial do serviço principal;
# + finalResponse - json|xml final inicial do serviço principal;
# + integrationType - define se é integração request ou response;
# + description - descrição do step;
# + return - possivel erro em alguma das etapas do logstash.
public isolated function integrationReqLogstash(string address, json|xml request, json|xml|error response,
        json|xml|error finalResponse, string integrationType, string description) returns error? {
    
    string statusCode = "200";
    json|xml|error integrationFinalResponse;
    if (response is ()) {
        integrationFinalResponse = "Nenhum valor encontrado.";
    } else {
        if (response is error) {
            statusCode = "500";
        }
        integrationFinalResponse = response;
    }

    string operation = "";
    if request is json {
        json[] serviceElements = <json[]> check request.serviceElements;
        operation = check serviceElements[0].code;
    }

    json finalRequest = {};
    if (request is json) {
        finalRequest = request;
        if (!request.toString().includes("correlationId")) {
            log:printInfo("Adding correlationId and operation");
            json mergeJson = {
                "correlationId": check request.externalId,
                "operation": operation
            };
            finalRequest = check request.mergeJson(mergeJson);
        }
    }else{
        json netqData = check NetQ:getDataFromNETQXml(request);
        finalRequest = netqData;
    }

    json integrationJson = {
        "description": description,
        "address": address,
        "status": statusCode
    };

    log:printInfo(integrationJson.toString());
    log:printInfo(request.toString());
    // Create and send integration log to Logstash
    json|error responseString = createRequestLogstash(finalRequest,
        integrationFinalResponse, null, integrationType,integrationJson);
    boolean _ = check sendRequestLogstash(check responseString);
}

# Function para registrar log de integração de banco ao logstash.
#
# + host - string com endereço a ser chamado;
# + request - json|xml request do serviço principal;
# + response - json|xml resultado inicial do serviço principal;
# + query - string query realizada;
# + integrationType - define se é integração request ou response;
# + description - descrição do step;
# + return - possivel erro em alguma das etapas do logstash.
public isolated function dbIntegrationReqLogstash(string host, json request, json|xml|error response,
        string integrationType, string query, string description) returns error? {
    
    string statusCode = "200";
    json|xml finalResponse;
    if (response is ()) {
        finalResponse = "Nenhum valor encontrado.";
    } else {
        if (response is error) {
            statusCode = "500";
        }
        
        finalResponse =  check response;
    }

    json integrationJson = {
        "address": host,
        "description": description,
        "status": statusCode, 
        "query": query
    };
    
    log:printInfo(integrationJson.toString());
    json finalRequest = request;
    if (!request.toString().includes("correlationId")) {
        log:printInfo("Adding correlationId");
        json mergeJson = {
            "correlationId": check request.idNetq
        };
        finalRequest = check request.mergeJson(mergeJson);
    }
    
    log:printInfo(finalRequest.toString());
    // Create and send integration log to Logstash
    json|error responseString = createRequestLogstash(finalRequest,
         finalResponse, null, integrationType,integrationJson);
    boolean _ = check sendRequestLogstash(check responseString);
}

# Function para criação da request ao Logstash
#
# + requestLog - xml enviado pelo ambiente;
# + responseLog - json|xml resultado do serviço principal;
# + initialRequest - xml inicial enviado pelo ambiente;
# + logType - string contendo o tipo de log que será gerado;
# + return - retorna a string para ser utilizada como request ao logstash.
public isolated function transformRequestLogstash(json|xml requestLog, json|xml|error responseLog,
                                         json|xml initialRequest, string logType) returns json|error {
    return createRequestLogstash(requestLog, responseLog, initialRequest,
    logType, null);
}

# Function para criação da request ao Logstash
#
# + requestLog - xml enviado pelo ambiente;
# + responseLog - json|xml resultado do serviço principal;
# + initialRequest - xml inicial enviado pelo ambiente;
# + logType - string contendo o tipo de log que será gerado;
# + integrationJson - json com informações de chamada externa;
# + return - retorna a string para ser utilizada como request ao logstash.
public isolated function createRequestLogstash(json|xml requestLog, json|xml|error responseLog,
                                         json|xml initialRequest, string logType, json integrationJson)
                                        returns json|error {
    log:printInfo("Iniciando criação de request para o Logstash");
    time:Utc currentUtc = time:utcNow();
    string utcString = time:utcToString(currentUtc);

    json generalRequestLogstash = {
        "context": "Solicitar Informações de Rede",
        "service": "Aprovisionador.SolicitarInformaçõesRede",
        "app_name": "api-aprovisionador-prd",
        "requestId": requestLog.correlationId is error? check requestLog.transactionId : check requestLog.correlationId,
        "operation": check requestLog.operation,
        "@timestamp": utcString
    };

    string message;
    if (responseLog is error) {
        message = " " + responseLog.message() 
        + " - Detail: " + responseLog.detail().toString()
        + " - Message: " + responseLog.toString();
    } else {
        message = responseLog.toString();
    }
    
    json especificsParams;
    if (logType == "START") {
        especificsParams = {
            "level": "30",                
            "description": "START - Inicialização do serviço",
            "message": initialRequest.toString()
        };
        log:printInfo("Format logstash start requisiton");
    } else if (logType == "REQ-INTEGRATION") {
        especificsParams = {
            "level": "30",
            "type": "request",
            "integration": true,
            "description": check integrationJson.description,
            "address": check integrationJson.address,
            "technology": "REST",
            "message": requestLog.toString()
        };
        log:printInfo("Format logstash external requisiton");
    } else if (logType == "RES-INTEGRATION") {
        especificsParams = {
            "level": "30",
            "description": check integrationJson.description,
            "type": "response",
            "integration": true,        
            "address": check integrationJson.address,
            "status": check integrationJson.status,
            "technology": "REST",
            "message": message
        };
        log:printInfo("Format logstash external response");
    } else if (logType == "BD-REQUEST") {
        especificsParams = {
            "level": "30",
            "description": check integrationJson.description,
            "type": "request",
            "integration": false,        
            "address": check integrationJson.address,
            "status": check integrationJson.status,
            "technology": "DBORACLE",
            "message": check integrationJson.query
        };
        log:printInfo("Format logstash database requisiton");
    } else if (logType == "BD-RESPONSE") {
        especificsParams = {
            "level": "30",
            "description": check integrationJson.description,
            "type": "response",
            "integration": false,        
            "address": check integrationJson.address,
            "status": check integrationJson.status,
            "technology": "DBORACLE",
            "message": message
        };
        log:printInfo("Format logstash database response");
    } else if (logType == "END") {
        especificsParams = {
            "level": "50",
            "description": "END - Finalização do serviço",
            "responseTime": check requestLog.responseTime,
            "status": check requestLog.status,
            "message": message
        };
        log:printInfo("Format logstash end requisiton");
    } else {
        log:printInfo("logType: " + logType);
        generalRequestLogstash = {
            "error": "No logType selected."
        };
        return generalRequestLogstash;
    }

    generalRequestLogstash = check generalRequestLogstash.mergeJson(especificsParams);
    log:printInfo("Logstash send message: " + generalRequestLogstash.toString());
    return generalRequestLogstash;
}