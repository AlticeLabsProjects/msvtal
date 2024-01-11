import ballerina/log;
import ballerina/time;

# Método responsável por realizar a transformação do request enviado pelo FFOne para o formato esperado
# pelo SOM.
#
# + responseBody - JSON da resposta assincrona enviada pelo FFOne.
# + return - XML no formato esperado pelo SOM para o envio da mensagem.
public isolated function transformFFOneResponse(json responseBody) returns xml|error {
    log:printInfo("Ajustando a resposta assincrona recebida do FFOne.");
    json data = check adaptFFOneAsyncResponse(responseBody);
    string correlationId = check data.correlationId;
    string state = "NCEGPON:" + <string>check data.state;
    string timeNow = time:utcToString(time:utcNow(2));
    timeNow = timeNow.substring(0, timeNow.length() - 2);
    string operation = check adaptFFOneOperation(data);
    xml response = xml
    `<soap-env:Body xmlns:soap-env='http://schemas.xmlsoap.org/soap/envelope/'>
        <ns1:notification xmlns:ns1='FTTHActivationInterface'>
            <correlationId>${correlationId}</correlationId>
            <code>${(check data.code).toString()}</code>
            <description>${state}</description>
            <executionDate>${timeNow}</executionDate>
            <operation>${operation}</operation>
            <BOLSO_OCS/>
        </ns1:notification>
    </soap-env:Body>`;
    return response;
}

# Função responsável pela extração dos dados necessários da resposta do FFOne.
#
# + responseBody - JSON de resposta enviada assincronamente pelo FFOne.
# + return - JSON com os dados necessários para a formatação completa da resposta ao SOM.
public isolated function adaptFFOneAsyncResponse(json responseBody) returns json|error {
    json serviceOrder = check responseBody.event.serviceOrder;
    string? externalId = check serviceOrder.externalId;
    string? state = check serviceOrder.state;
    json[]|error orderItemArray = <json[]|error>serviceOrder.orderItem;
    if orderItemArray is error {
        log:printError("Não foi possivel encontrar o OrderItem", id = externalId);
        return orderItemArray;
    }
    string action = check orderItemArray[0].action;
    string finalState = "";

    int code = 400;
    string externalIdFinal = "";
    if state is string && state.trim() == "Completed" {
        code = 0;
        finalState = "Sucesso";
        log:printInfo("Processamento da ordem está completo por parte do FFOne.", id = externalId);
    } else {
        log:printInfo("Processamento da ordem está com estado de falha.", id = externalId);
        finalState = "Falha";
    }
    if externalId is string {
        log:printInfo("ExternalId - " + externalId);
        int? firstIndex = externalId.indexOf(":");
        int? lastIndex = externalId.lastIndexOf(":");
        if firstIndex is int && lastIndex is int {
            externalIdFinal = externalId.substring(firstIndex + 1, lastIndex);
        } else {
            externalIdFinal = externalId;
        }
        log:printInfo("Final ExternalId - " + externalIdFinal);
    }

    return {
        correlationId: externalIdFinal,
        code: code,
        state: finalState,
        operation: action
    };
}

# Função responsável por adaptar o nome da operação de acordo com o valor enviado pelo FFOne.
#
# + data - JSON com os dados já separados enviados pelo FFOne
# + return - string com o valor da operação que deve ser enviada ao SOM
public isolated function adaptFFOneOperation(json data) returns string|error{
    string operation = check data.operation;
    match operation.toLowerAscii(){
        "modifyont" => {
            operation = "ASSOCIAR_ONT_APC";
        }
    }
    return operation;
}
