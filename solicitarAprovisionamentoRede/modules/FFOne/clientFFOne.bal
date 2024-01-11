import ballerina/http;
import ballerina/os;
import ballerina/log;

# Função responsável pelo envio do request ao FFOne.
#
# + request - JSON já formatado para o envio ao FFOne.
# + return - JSON recebido da chamada ao FFOne.
public isolated function sendRequestFFOne(json request) returns json|error {
    string urlFFOne = os:getEnv("INTNOSSIS-URL-FFONE");
    string uriFFOne = os:getEnv("INTNOSSIS-URI-FFONE");
    string userFFOne = os:getEnv("INTNOSSIS-USR-FFONE");
    string passwordFFOne = os:getEnv("INTNOSSIS-PSW-FFONE");
    log:printInfo("Url a ser chamada", url = urlFFOne+uriFFOne);
    http:Client ffoneServer = check new (urlFFOne,
        retryConfig = {interval: 5, count: 3},
        auth = {
            username: userFFOne,
            password: passwordFFOne
        },
        secureSocket = {
            cert: "./certs/_.aws.vtal.crt"
        },
        httpVersion = http:HTTP_1_1
    );
    json|error response = check ffoneServer->post(uriFFOne, request);
    if response is error {
        log:printError("Error ao fazer conexão com o FFOne", response);
        return response;
    }
    string? failed = check response?.message;
    if failed is string {
        log:printError("Ocorreu uma falha ao criar a ordem de serviço. Mensagem - " + failed);
    }
    log:printInfo("Resposta recebida do FFOne", response = response);
    return response;
}
