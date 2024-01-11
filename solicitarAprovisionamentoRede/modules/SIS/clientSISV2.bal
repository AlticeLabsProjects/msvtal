import ballerina/http;
import ballerina/os;
import ballerina/log;

# Função responsável pelo envio da requisição ao SIS V2 (SOA).
#
# + request - XML para o envio ao SOA.
# + return - XML de resposta do SOA ou erro recebido ao realizar a requisição.
public isolated function sendRequestSISV2(xml request) returns xml|error {
    string urlSOAVTal = os:getEnv("INTNOSSIS-URL-SOA");
    string uriSOAVTal = os:getEnv("INTNOSSIS-URI-SOA");
    log:printInfo("Url a ser chamada", url = urlSOAVTal+uriSOAVTal);
    http:Client SISV2Server = check new (urlSOAVTal,
        retryConfig = {interval: 5, count: 3}
    );
    xml|error response = check SISV2Server->post(uriSOAVTal, request);
    if response is error {
        log:printError("Error ao fazer conexão com o FFOne", response);
        return response;
    }
    string? failed = check response?.message;
    if failed is string {
        log:printError("Ocorreu uma falha ao criar a ordem de serviço. Mensagem - " + failed);
    }
    log:printInfo("Resposta SIS Oi", response = response);
    return response;

}
