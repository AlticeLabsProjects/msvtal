import ballerina/log;
import ballerina/time;

# Function para unir processos da request inicial ao logstash.
#
# + initialPayload - json enviado pelo ambiente;
# + selectedSystem - ambiente de destino;
# + return - possivel erro em alguma das etapas do logstash.
public isolated function initialReqLogstash(json initialPayload, string selectedSystem) returns json|error? {

    json adaptPayload = check createAdaptPayload(initialPayload, selectedSystem);
    // Create and send initial log to Logstash 
    json|error requestString = transformRequestLogstash(adaptPayload,
    null, initialPayload, "START");
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
public isolated function integrationReqLogstash(string address, json request, json|error response,
        json|xml|error finalResponse, string integrationType, string description) returns error? {

    string statusCode = "200";
    json|xml|error integrationFinalResponse;
    if (response is ()) {
        integrationFinalResponse = "Nenhum valor encontrado.";
    } else {
        integrationFinalResponse = response;

        if (response is error) {
            statusCode = "500";
        }
    }

    json finalRequest = request;
    if (!request.toString().includes("correlationId")) {
        log:printInfo("Adding correlationId");
        json mergeJson = {
            "correlationId": check request.netqId
        };
        finalRequest = check request.mergeJson(mergeJson);
    }

    json integrationJson = {
        "description": description,
        "address": address,
        "status": statusCode
    };

    log:printInfo(integrationJson.toString());
    log:printInfo(finalRequest.toString());
    // Create and send integration log to Logstash
    json|error responseString = createRequestLogstash(finalRequest,
        integrationFinalResponse, null, integrationType, integrationJson);
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

    json generalRequestLogstash;
    if (requestLog is null || requestLog is ()) {
        log:printInfo("RequestLogstash é nulo");
        generalRequestLogstash = {
            "context": "Solicitar Aprovisionamento de Rede",
            "service": "Aprovisionador.RetornarInformaçõesRede",
            "app_name": "api-aprovisionador-prd",
            "@timestamp": utcString
        };
    } else {
        log:printInfo("RequestLogstash não é nulo");
        generalRequestLogstash = {
            "context": "Solicitar Aprovisionamento de Rede",
            "service": "Aprovisionador.RetornarInformaçõesRede",
            "app_name": "api-aprovisionador-prd",
            "requestId": check requestLog.correlationId,
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
        } else if (logType == "END") {
            especificsParams = {
                "level": "50",
                "description": "END - Finalização do serviço",
                "responseTime": check requestLog.responseTime,
                "status": 200,
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
    }

    log:printInfo("Logstash send message: " + generalRequestLogstash.toString());
    return generalRequestLogstash;
}

public isolated function isFFOne(string selectedSystem) returns boolean {
    return selectedSystem == "FFONE";
}

# Description.
#
# + selectedSystem - parameter description
# + return - return value description
public isolated function isSIS(string selectedSystem) returns boolean {
    return selectedSystem == "SIS";
}

public isolated function createAdaptPayload(json initialPayload, string system) returns json|error {

    string correlationId = "";
    string operation = "";
    if isFFOne(system) {
        correlationId = check initialPayload?.event?.serviceOrder?.externalId;
        // FFOne por enquanto só trata essa operação
        operation = "GPON_ESTADO_ONT";
    }
    if isSIS(system) {
        json[] serviceElements = <json[]>check initialPayload.serviceElements;
        operation = serviceElements[0].code is error ? "GPON_ESTADO_ONT" : check serviceElements[0].code;
        correlationId = check initialPayload?.externalId;
    }
    return {
        "correlationId": correlationId,
        "operation": operation
    };
}
