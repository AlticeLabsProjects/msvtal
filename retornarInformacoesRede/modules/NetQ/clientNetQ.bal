import ballerina/http;
import ballerina/log;
import retornarInformacoesRede.Logstash;

# Função responsável por enviar a requisição recebida pelos ambientes ao netq.
#
# + requestJson - JSON a ser enviado ao netq
# + urlNetq - string que representa a url a ser chamada do netq
# + uriNetq - string que representa a uri a ser chamada do netq
# + return - resposta que o netq envia ao MS
public isolated function sendRequestNetQ(json requestJson, string urlNetq, string uriNetq) returns json|error {

    http:Client netqServer = check new (urlNetq,
        retryConfig = {
            interval: 5,
            count: 3
        }
    );

    string urlFinal = urlNetq + uriNetq;
    json initialRequestJson = requestJson;
    error? integrationReqLogstash = Logstash:integrationReqLogstash(urlFinal,
         initialRequestJson, null, null,"REQ-INTEGRATION", "INVOKE - Request enviado ao NetQ");
    
    json|error response = check netqServer->post(uriNetq, requestJson);

    error? integrationReqLogstashResult = Logstash:integrationReqLogstash(urlFinal,
        initialRequestJson, response, response,"RES-INTEGRATION", "RESPONSE - Response recebido do NetQ");
    if (integrationReqLogstash is error || integrationReqLogstashResult is error) {
        log:printError("Erro ao realizar a chamada ao Logstash", integrationReqLogstashResult);
    }

    if response is error {
        log:printError("Error ao fazer conexão com o NetQ", response);
        return response;
    }
    return response;

}