import ballerina/http;
import ballerina/os;
import ballerina/log;
import ballerina/time;
import ballerina/regex;

# Função responsável pelo envio de logs ao logstash.
#
# + request - String contendo o log.
# + return - Boolean confirmando ou não o sucesso da operação.
public isolated function sendRequestLogstash(json request) returns boolean|error {

    // INTNOSSIS-URL-LOGSTASH: ordehx01.local:9200
    // INTNOSSIS-URI-LOGSTASH: /api-appointment-dev-%s/_doc

    string urlLogstashVTal = os:getEnv("INTNOSSIS-URL-LOGSTASH");
    string uriLogstashVTal = os:getEnv("INTNOSSIS-URI-LOGSTASH");
    
    
    http:Client LogstashServer = check new (urlLogstashVTal,
        retryConfig = {interval: 5, count: 3},
        secureSocket = {
            enable: false
        },
        httpVersion = http:HTTP_1_1    
    );

    time:Utc currentUtc = time:utcNow();
    string utcString = time:utcToString(currentUtc);
    string dataSegment = regex:split(utcString, "T")[0];
    string formattedDate = regex:replaceAll(dataSegment, "-", ".");
    string formattedUri = regex:replace(uriLogstashVTal, "%s", formattedDate);
    log:printInfo("Url a ser chamada", url = urlLogstashVTal+formattedUri);

    map<(string|string[])>? headers = {
        "Content-Type": "application/json",
        "Authorization": "Basic YWRtaW46U3Vwb3J0M0BvaQ=="
    };

    json|error response = LogstashServer->post(formattedUri, request, headers);
    if response is error {
        log:printError("Error ao fazer conexão com o Logstash",response);
        return false;
    }
    string? failed = check response?.message;
    if failed is string {
        log:printError("Ocorreu uma falha ao enviar log da operação serviço."
            + "Mensagem - " + failed);
        return false;
    }
    log:printInfo("Resposta Logstash", response = response);
    return true;
}
