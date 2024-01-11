import ballerina/http;
import ballerina/time;
import ballerina/log;
import solicitarInformacoesRede.logic;
import solicitarInformacoesRede.Logstash;

@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"],
        allowCredentials: true,
        allowMethods: ["POST"]
    }
}
service / on new http:Listener(8080) {

    # Resource para o recebimento de request para T&D.
    #
    # + payload - XML enviado pelo ambiente;
    # + return - Possivel erro em alguma das etapas da orquestração.
    isolated resource function post solicitarInformacoesRede(@http:Payload xml payload) returns json|xml|error? {
        time:Utc initTime = time:utcNow();
        int initTimeInMills = <int>(<decimal>initTime[0] + initTime[1]) * 1000;
        log:printInfo("Request que chegou ao MS");
        log:printInfo(payload.toString());
        json initialReqLogstash = check Logstash:initialReqLogstash(payload);   

        // Main method
        json|xml|error responseOrchestration = logic:requestOrchestration(payload);

        time:Utc finalTime = time:utcNow();
        int finalTimeInMills = (<int>(<decimal>finalTime[0] + finalTime[1]) * 1000) - initTimeInMills;   
        error? finalReqLogstash = Logstash:finalReqLogstash(initialReqLogstash, responseOrchestration, finalTimeInMills);
        if (initialReqLogstash is () || finalReqLogstash is error) {
            log:printError("Erro ao realizar a chamada ao Logstash", finalReqLogstash);
        }

        if responseOrchestration is error{
            log:printError("Houve um erro na orquestração do request");
            return responseOrchestration;
        }

        return responseOrchestration;
    }
}