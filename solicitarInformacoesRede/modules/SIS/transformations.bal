import ballerina/log;
import ballerina/os;

# Função responsável pela transformação dos dados recebidos para o formato esperado pelo SIS VTal.
#
# + data - JSON com os dados ja extraidos do request enviado pelo NetQ.
# + return - return value description
public isolated function transformSISVTalRequest(json data) returns json|error {
    string urlSISCallback = os:getEnv("INTNOSSIS-SIS-DIAG-CALLBACK");
    int prioridade = check int:fromString(check data.prioridade);
    json requestSISVTal = {        
        "systemId": "NETQ",
        "externalId": check data.idNetq,
        "priority": prioridade,
        "timeToLive": 120000,
        "endpointReply":urlSISCallback,
        "url": check data.url,
        "serviceElements": [
            {
                "code": check data.operation,
                "parameters": [
                    check data.parameters
                ]
            }
        ]
    };
    
    log:printInfo("Request transformada", id = check data.idNetq);
    log:printInfo(requestSISVTal.toString());
    return requestSISVTal;
}