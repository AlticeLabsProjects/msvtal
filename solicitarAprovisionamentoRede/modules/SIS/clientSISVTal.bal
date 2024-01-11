import ballerina/http;
import ballerina/os;
import ballerina/log;

# Método responsável pelo envio da requisição ao SIS VTal.
#
# + request - JSON de request formatado para o envio.
# + return - Response sincrono recebido por parte do SIS.
public isolated function sendRequestSISVTal(json request) returns json|error {
    string urlSISVTal = os:getEnv("INTNOSSIS-URL-SISVTal");
    string uriSISVTal = os:getEnv("INTNOSSIS-URI-SISVTal");
    log:printInfo("Url a ser chamada", url = urlSISVTal+uriSISVTal);
    http:Client SISVtalServer = check new (urlSISVTal,
        retryConfig = {interval: 5, count: 3}
    );
    json|error response = check SISVtalServer->post(uriSISVTal, request);
    if response is error {
        log:printError("Error ao fazer conexão com o SIS", response);
        return response;
    }
    string? failed = check response?.message;
    if failed is string {
        log:printError("Ocorreu uma falha ao criar a ordem de serviço. Mensagem - " + failed);
    }
    log:printInfo("Resposta SIS Oi", response = response);
    return response;
}
