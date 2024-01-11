import ballerina/http;
import retornarAprovisionamentoRede.logic;
import ballerina/log;

@http:ServiceConfig{
    cors: {
        allowOrigins: ["*"],
        allowCredentials: true,
        allowMethods: ["POST"]
    }
}
service / on new http:Listener(8080) {
    # Resource para o recebimento do response assincrono originado do FFOne.
    #
    # + payload - JSON enviado pelo FFOne;
    # + return - Possivel erro em alguma das etapas da orquestração.
    isolated resource function post retornarAprovisionamentoRedeFFone(@http:Payload json payload) returns json|xml|error {
        log:printInfo("payload recebido pelo FFOne", payload = payload.toString());
        xml|error responseOrchestration = logic:requestOrchestrationFFOne(payload);
        if responseOrchestration is error{
            log:printError(responseOrchestration.toString());
        }
        return responseOrchestration;
    }
    
    # Resource para o recebimento do response assincrono originado do SIS.
    #
    # + payload - JSON enviado pelo SIS;
    # + return - Possivel erro em alguma das etapas da orquestração.
    isolated resource function post retornarAprovisionamentoRedeSIS(@http:Payload json payload) returns json|xml|error? {
        log:printInfo("payload recebido pelo SIS", payload = payload.toString());
        xml|error responseOrchestration = logic:requestOrchestrationSIS(payload);
        if responseOrchestration is error{
            log:printError(responseOrchestration.toString());
        }
        return responseOrchestration;
    }
}