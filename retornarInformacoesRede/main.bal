import ballerina/http;
import ballerina/log;
import ballerina/time;
import retornarInformacoesRede.Logstash;
import retornarInformacoesRede.logic;

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
    isolated resource function post retornarInformacoesRedeFFOne(@http:Payload json payload) returns json|error? {
        time:Utc initTime = time:utcNow();
        int initTimeInMills = <int>(<decimal>initTime[0] + initTime[1]) * 1000;
        log:printInfo("payload recebido pelo FFOne", payload = payload.toString());
        json initialReqLogstash = check Logstash:initialReqLogstash(payload, "FFONE");   

        // Main method
        error? responseOrchestration = logic:requestOrchestrationFFOne(payload);
        if responseOrchestration is error{
            log:printError(responseOrchestration.toString());
        }

        time:Utc finalTime = time:utcNow();
        int finalTimeInMills = (<int>(<decimal>finalTime[0] + finalTime[1]) * 1000) - initTimeInMills;   
        if (initialReqLogstash is null || initialReqLogstash is ()) {
            log:printError("Erro ao realizar a chamada ao Logstash", initialReqLogstash);
        } else {
            log:printInfo("Chamada inicial ao Logstash com sucesso");
            error? finalReqLogstash = Logstash:finalReqLogstash(initialReqLogstash,responseOrchestration, finalTimeInMills);
        }

        return responseOrchestration;
    }
    
    # Resource para o recebimento do response assincrono originado do SIS.
    #
    # + payload - JSON enviado pelo SIS;
    # + return - Possivel erro em alguma das etapas da orquestração.
    isolated resource function post retornarInformacoesRedeSIS(@http:Payload json payload) returns json|error? {
        time:Utc initTime = time:utcNow();
        int initTimeInMills = <int>(<decimal>initTime[0] + initTime[1]) * 1000;

        log:printInfo("payload recebido pelo SIS", payload = payload.toString());
        json initialReqLogstash = check Logstash:initialReqLogstash(payload, "SIS");   

        error? responseOrchestration = logic:requestOrchestrationSIS(payload);
        if responseOrchestration is error{
            log:printError(responseOrchestration.toString());
        }   

        time:Utc finalTime = time:utcNow();
        int finalTimeInMills = (<int>(<decimal>finalTime[0] + finalTime[1]) * 1000) - initTimeInMills;   
        if (initialReqLogstash is null || initialReqLogstash is ()) {
            log:printError("Erro ao realizar a chamada ao Logstash", initialReqLogstash);
        } else {
            log:printInfo("Chamada inicial ao Logstash com sucesso");
            error? finalReqLogstash = Logstash:finalReqLogstash(initialReqLogstash,responseOrchestration, finalTimeInMills);
        }

        return responseOrchestration;
    }
}