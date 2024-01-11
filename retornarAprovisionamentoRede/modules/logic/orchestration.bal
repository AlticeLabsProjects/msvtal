import retornarAprovisionamentoRede.SOM;
import retornarAprovisionamentoRede.FFOne;
import retornarAprovisionamentoRede.SIS;
import ballerina/os;
import ballerina/log;

# Função responsável por realizar a orquestração do response recebido do FFOne.
#
# + FFOneRequest - JSON recebido do FFOne
# + return - Erro em caso de falha na postagem da fila do SOM.
public isolated function requestOrchestrationFFOne(json FFOneRequest) returns xml|error {
    string correlationId = check FFOneRequest.event.serviceOrder.externalId;
    xml|error requestSOM = FFOne:transformFFOneResponse(FFOneRequest);
    if requestSOM is error {
        log:printError("Erro ao realizar a transformação do request ao SOM", id = correlationId);
        return requestSOM;
    }
    string somState = os:getEnv("INTNOSSIS-SOM-STATE");
    if (somState == "false") {
        log:printInfo("Flag mock ativada. Enviando o request para o SIS Oi para encaminhar ao SOM", id = correlationId);
        log:printInfo(requestSOM.toString());
        xml|error responseSIS = SIS:sendRequestSISV2(requestSOM);
        if responseSIS is error{
            log:printError("Erro ao realizar a chamada ao SIS.", id = correlationId);
        }
        return responseSIS;     
    }
    log:printInfo("Postando a request na fila do SOM", id = correlationId, request = requestSOM);
    error? responseSOM = SOM:postMessageSOM(requestSOM);
    if responseSOM is error {
        log:printError("Erro ao postar a mensagem na fila do SOM", id = correlationId);
        return responseSOM;
    }
    
    //Analisar se o retorno do SOM realmente só será um possível erro
    return requestSOM;
}

# Função responsável por realizar a orquestração do response recebido do SIS.
#
# + SISRequest - JSON recebido do SIS
# + return - Erro em caso de falha na postagem da fila do SOM.
public isolated function requestOrchestrationSIS(json SISRequest) returns xml|error {
    string externalId = check SISRequest.externalId;
    xml|error requestSOM = SIS:adaptSISV2AsyncResponse(SISRequest);
    if requestSOM is error {
        log:printError("Erro ao realizar a transformação do request ao SOM", id = externalId);
        return requestSOM;
    }
    string somState = os:getEnv("INTNOSSIS-SOM-STATE");
    if (somState == "false") {
        log:printInfo("Flag mock ativada. Enviando o request para o SIS Oi para encaminhar ao SOM", id = externalId);
        log:printInfo(requestSOM.toString());
        xml|error responseSIS = SIS:sendRequestSISV2(requestSOM);
        if responseSIS is error{
            log:printError("Erro ao realizar a chamada ao SIS.", id = externalId);
        }
        return responseSIS;   
    }
    log:printInfo("Postando a request na fila do SOM", id = externalId, request = requestSOM);
    error? responseSOM = SOM:postMessageSOM(requestSOM);
    if responseSOM is error {
        log:printError("Erro ao postar a mensagem na fila do SOM", responseSOM, id = externalId);
        return responseSOM;
    }

    //Analisar se o retorno do SOM realmente só será um possível erro
    return requestSOM;
}