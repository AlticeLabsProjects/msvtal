import ballerina/http;
import ballerina/os;
import ballerina/log;
import solicitarInformacoesRede.NetQ;
import solicitarInformacoesRede.Logstash;

# Método responsável pelo envio da requisição ao SIS VTal.
#
# + request - JSON de request formatado para o envio.
# + return - Response sincrono recebido por parte do SIS.
public isolated function sendRequestSISVTal(json request) returns xml|error {
    string urlSISVTal = os:getEnv("INTNOSSIS-URL-SISVTal");
    string uriSISVTal = os:getEnv("INTNOSSIS-URI-SISVTal");
    http:Client SISVtalServer = check new (urlSISVTal,
        retryConfig = {interval: 5, count: 3}
    );

    string urlFinal = urlSISVTal + uriSISVTal;
    json|error response = SISVtalServer->post(uriSISVTal, request);
    error? integrationReqLogstash = Logstash:integrationReqLogstash(urlFinal,
         request, null, null, "REQ-INTEGRATION", "INVOKE - Request enviado ao SISVtal");

    xml|error finalResponse = NetQ:transformResponseNetq(response);

    error? integrationReqLogstashResult = Logstash:integrationReqLogstash(urlFinal,
        request, response, finalResponse,"RES-INTEGRATION", "RESPONSE - Response recebido do SISVtal");
    if (integrationReqLogstash is error || integrationReqLogstashResult is error) {
        log:printError("Erro ao realizar a chamada ao Logstash", integrationReqLogstashResult);
    }

    return finalResponse;
}