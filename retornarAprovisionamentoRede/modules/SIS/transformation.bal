import ballerina/log;
import ballerina/time;

# Função responsável pela adaptação do request recebido do SIS VTal para o formato esperado pelo SOM.
#
# + SisV2Response - JSON de resposta enviado pelo SIS assincronamente.
# + return - XML formatado para o envio ao SOM.
public isolated function adaptSISV2AsyncResponse(json SisV2Response) returns xml|error{
    string externalId = check SisV2Response.externalId;
    log:printInfo("AJusatando a resposta assíncrona do SIS", id = externalId);
    string timeNow = time:utcToString(time:utcNow(2));
    timeNow = timeNow.substring(0, timeNow.length() - 2);
    string code = "0";
    json[] serviceElements = <json[]> check SisV2Response.serviceElements;
    string description = check serviceElements[0].response.'type;
    string operation = check serviceElements[0].code;
    // Mapeando pelo campo Type, que se provou mais constante
    if !description.includes("Success"){
        log:printInfo("SIS retornou um erro");
        code = "400";
    }
    xml response = xml
    `<soap-env:Body xmlns:soap-env='http://schemas.xmlsoap.org/soap/envelope/'>
            <ns1:notification xmlns:ns1='FTTHActivationInterface'>
                <correlationId>${externalId}</correlationId>
                <code>${code}</code>
                <description>${description}</description>
                <executionDate>${timeNow}</executionDate>
                <operation>${operation}</operation>
                <BOLSO_OCS/>
            </ns1:notification>
        </soap-env:Body>`;
    return response;
}