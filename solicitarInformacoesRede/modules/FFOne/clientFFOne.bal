import ballerina/http;
import ballerina/os;
import solicitarInformacoesRede.NetQ;
import solicitarInformacoesRede.Logstash;
import ballerina/log;

# Função responsável pelo envio do request ao FFOne.
#
# + request - JSON já formatado para o envio ao FFOne.
# + return - JSON recebido da chamada ao FFOne.
public isolated function sendRequestFFOne(json request) returns xml|error {
    string urlFFOne = os:getEnv("INTNOSSIS-URL-FFONE");
    string uriFFOne = os:getEnv("INTNOSSIS-URI-FFONE");
    string userFFOne = os:getEnv("INTNOSSIS-USR-FFONE");
    string passwordFFOne = os:getEnv("INTNOSSIS-PSW-FFONE");
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

    string urlFinal = urlFFOne + uriFFOne;
    error? integrationReqLogstash = Logstash:integrationReqLogstash(urlFinal,
         request, null, null, "REQ-INTEGRATION", "INVOKE - Request enviado ao FFOne");
    
    json|error response = ffoneServer->post(uriFFOne, request);
    xml|error finalResponse = NetQ:transformResponseNetq(response);

    error? integrationReqLogstashResult = Logstash:integrationReqLogstash(urlFinal,
        request, response, finalResponse,"RES-INTEGRATION", "RESPONSE - Response recebido do FFOne");
    if (integrationReqLogstash is error || integrationReqLogstashResult is error) {
        log:printError("Erro ao realizar a chamada ao Logstash", integrationReqLogstashResult);
    }

    return finalResponse;
}
