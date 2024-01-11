import ballerina/http;
import ballerina/os;
import ballerina/log;
import solicitarInformacoesRede.Logstash;

# Função responsável pelo envio da requisição ao SIS V2 (SOA).
#
# + request - XML para o envio ao SOA.
# + return - XML de resposta do SOA ou erro recebido ao realizar a requisição.
public isolated function sendRequestSISV2(xml request) returns xml|error {
    string urlSOAVTal = os:getEnv("INTNOSSIS-URL-SOA");
    string uriSOAVTal = os:getEnv("INTNOSSIS-URI-SOA");
    log:printInfo("Url a ser chamada " + urlSOAVTal);
    http:Client SISV2Server = check new (urlSOAVTal,
        retryConfig = {interval: 5, count: 3}
    );
    
    string urlFinal = urlSOAVTal + uriSOAVTal;
    error? integrationReqLogstash = Logstash:integrationReqLogstash(urlFinal,
         request, null, null, "REQ-INTEGRATION", "INVOKE - Request enviado ao SISV2");

    xml|error response = SISV2Server->post(uriSOAVTal, request);

    error? integrationReqLogstashResult = Logstash:integrationReqLogstash(urlFinal,
        request, response, response,"RES-INTEGRATION", "RESPONSE - Response recebido do SISV2");
    if (integrationReqLogstash is error || integrationReqLogstashResult is error) {
        log:printError("Erro ao realizar a chamada ao Logstash", integrationReqLogstashResult);
    }

    if response is error {
        log:printError("Error ao fazer conexão com o FFOne", response);
        return response;
    }
    string? failed = check response?.message;
    if failed is string {
        log:printError("Ocorreu uma falha ao criar a ordem de serviço. Mensagem - " + failed);
    }
    return response;

}
