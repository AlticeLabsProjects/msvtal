import ballerina/regex;
import ballerina/log;

public type NetqPathRequest record {
    string urlNetq;
    string uriNetq;
};

# Função responsável pelo ajuste do response assincrono recebido por parte do SIS para o formato # esperado pelo NetQ.
#
# + jsonResponseSISVTal - JSON recebido como resposta assincrona do SISVTal.
# + return - Retorna JSON formatado para o envio ao NetQ.
public isolated function transformSISVTalNetRequest(json jsonResponseSISVTal) returns json|error {
    log:printInfo("Ajustando a resposta assincrona fornecida pelo SIS VTal.");
    json data = check adaptSISV2AsyncResponse(jsonResponseSISVTal);

    return {
        "netqId": check data.netqId,
        "sisId": check data.sisId,
        "operation": check data.operation,
        "status": {
            "code": check data.code,
            "description": check data.description
        },
        "response": {
            "networkResponse": check data.networkResponse
        }
    };
}

# Função responsável por passar as informações recebidas do diagnostico para a codificação Base64 
# e extrair os dados necessários para o mapeamento.
#
# + responseBody - JSON com os dados obtidos a partir da resposta do SIS VTal.
# + return - return value description
public isolated function adaptSISV2AsyncResponse(json responseBody) returns json|error {
    json[] serviceElements = <json[]>check responseBody.serviceElements;
    json response = check serviceElements[0].response;
    json[] responseDetails = <json[]>check response.details;

    string operation = serviceElements[0].code is error ? "GPON_ESTADO_ONT" : check serviceElements[0].code;
    string code = "";
    string description = "";

    string vendor = "";
    json[] initialParameters = <json[]>check serviceElements[0].parameters;
    foreach var initialPar in initialParameters {
        if initialPar.toString().includes("VENDOR") {
            vendor = regex:split(initialPar.toString(), "\":")[1];
            vendor = regex:replaceAll(vendor, "\"}|\"", "");
        }
    }
    log:printInfo("Vendor found", vendor = vendor);

    json[] elements = [];
    string? state = check response?.'type;

    foreach var networkElement in responseDetails {

        string elementName = networkElement.networkElement is error|() ? "" : check networkElement.networkElement;
        string stateDescription = networkElement.description is error|() ? "" : check networkElement.description;
        if state is string && state.trim() == "Success" {
            code = "Success";
            description = description.concat(elementName + " - " + stateDescription + " ");
        } else {
            code = "Falha";
            description = description.concat(elementName + " - " + stateDescription + " ");
        }
        json[] searchParameters = <json[]>check networkElement.searchParameters;
        foreach json data in searchParameters {
            string dataString = regex:split(data.toString(), "\\:")[0];
            if !elements.toString().includes(dataString) {
                elements.push(data);
            }
        }

    }

    json networkResponse = {};
    if elements.length() != 0 {

        json searchParameters = check createSearchParameters(elements, operation, vendor);
        log:printInfo("Json gerado");
        log:printInfo(searchParameters.toString());

        networkResponse = {
            SearchParameters: searchParameters
        };
    }

    string id = check responseBody?.externalId;

    json adaptSISVTalResponse = {
        netqId: id,
        sisId: id,
        operation: operation,
        code: code,
        description: description,
        networkResponse: networkResponse.toString()
    };

    log:printInfo("Resposta SIS VTal adaptada");
    log:printInfo(adaptSISVTalResponse.toString());
    return adaptSISVTalResponse;
}

# Função responsável por encontrar o caminho a ser chamado no NetQ recebido.
#
# + request - JSON recebido da rede
# + return - Valores de url/uri a serem chamados ou Erro em casa de falha na busca
public isolated function adaptNetqPath(json request) returns NetqPathRequest|error {
    string? urlCompleta = check request?.url;
    if urlCompleta is string {
        int initIndex = <int>urlCompleta.lastIndexOf(":");
        int endIndex = <int>urlCompleta.indexOf("/", initIndex);
        string url = urlCompleta.substring(0, endIndex);
        string uri = urlCompleta.substring(endIndex);
        NetqPathRequest netqPath = {urlNetq: url, uriNetq: uri};
        log:printInfo("Url a ser chamada: " + netqPath.toString());
        return netqPath;
    }
    log:printError("Erro ao encontrar a url na request recebida");
    return error("Erro ao encontrar a url na request recebida");
}

# Função responsável por criar o objeto SearchParameters a ser enviado ao netq.
#
# + itemList - lista com todos os parâmetros a serem incluídos
# + operation - string que define qual operação está sendo realizada
# + vendor - string que define qual o vendor da operação
# + return - JSON que será utilizado no envio ao netq
public isolated function createSearchParameters(json[] itemList, string operation, string vendor) returns json|error {
    log:printInfo("operation", value = operation);
    map<json> parametersMap = {};
    foreach json item in itemList {
        parametersMap = check parametersMap.mergeJson(item).ensureType();
    }
    json scheduler = {};
    json macAddressData = {};
    json withNumbers = {};
    json noDots = {};
    json withDots = {};
    string[] keysWithNumbers = [];
    foreach [string, json] [key, value] in parametersMap.entries() {
        boolean hasNumber = false;
        if key.includes("PORTA_ETHERNET") {
            log:printInfo("Porta Ethernet");
            log:printInfo(value.toString());
            string portaEthernetStr = regex:replace(value.toString(), "\"", "");
            log:printInfo(portaEthernetStr);
            noDots = check noDots.mergeJson({[key] : portaEthernetStr});
            continue;
        }
        //Ajuste SCHEDULER e MACADDRESS que estão com formato diferente da regra
        if operation == "GPON_ESTADO_ONT" {
            // Esse espaço deve ser comentado assim que a vtal ajeitar a regra
            if key.includes("SCHEDULER") {
                log:printInfo("scheduler", item = value);
                scheduler = check scheduler.mergeJson({[key] : value});
                continue;
            }
            if key.includes("MACADDRESS") {
                macAddressData = check macAddressData.mergeJson({[key] : value});
                continue;
            }
        }
        if !key.includes(".") {
            noDots = check noDots.mergeJson({[key] : value});
            continue;
        }
        string[] keyAttributes = regex:split(key, "\\.");

        string objectString = "";
        string keyNumber = "";
        string fullKeyNumber = "";
        foreach int i in 0 ... keyAttributes.length() - 1 {
            string attribute = keyAttributes[i];

            if int:fromString(attribute) !is error {
                keyNumber = fullKeyNumber.concat(attribute);
                hasNumber = true;
            }
            fullKeyNumber = fullKeyNumber.concat(attribute, ".");
            objectString = objectString.concat(":{", "\"", attribute, "\"");
        }
        if keysWithNumbers.indexOf(keyNumber) == () && keyNumber != "" {

            keysWithNumbers.push(keyNumber);
        }

        objectString = objectString.concat(": \"", value.toString(), "\"");
        foreach int i in 1 ... keyAttributes.length() {
            objectString = objectString.concat("}");
        }
        objectString = objectString.substring(1);

        if hasNumber {
            withNumbers = check withNumbers.mergeJson(check objectString.fromJsonString());
        } else {
            withDots = check withDots.mergeJson(check objectString.fromJsonString());

        }
    }
    json finalSearchParameters = {};
    if keysWithNumbers.length() == 0 {
        finalSearchParameters = check withDots.mergeJson(noDots);
        match operation {
            "GPON_ESTADO_ONT" => {
                finalSearchParameters = check configureGponEstadoOnt(finalSearchParameters, scheduler, macAddressData, vendor);
            }
            "GPON_OLT_TRAFFIC" => {
                finalSearchParameters = check configureGponOltTraffic(finalSearchParameters, vendor);
            }
        }
        return finalSearchParameters;
    }

    withDots = check withDots.mergeJson(noDots);
    keysWithNumbers = keysWithNumbers.sort();

    json withNumbersAdapted = check adaptNumberJson(withNumbers, keysWithNumbers);

    withDots = check withDots.mergeJson(withNumbersAdapted);
    finalSearchParameters = withDots;
    match operation {
        "GPON_ESTADO_ONT" => {
            finalSearchParameters = check configureGponEstadoOnt(finalSearchParameters, scheduler, macAddressData, vendor);
        }
        "GPON_OLT_TRAFFIC" => {
            finalSearchParameters = check configureGponOltTraffic(finalSearchParameters, vendor);
        }
    }

    return finalSearchParameters;
}

# Função responsável por adaptar os dados para a operação GPON_OLT_TRAFFIC.
#
# + completeJson - JSON completo com todos os parâmetros de busca oriundos da requisição
# + vendor - string do vendor da requisição
# + return - JSON do searchParameters adaptado ou mensagem de erro ao buscar algum dado mandatório inexistente
public isolated function configureGponOltTraffic(json completeJson, string vendor) returns json|error {
    json portsData = {};
    if !vendor.includes("ZTE"){
        return completeJson;
    }
    portsData = check completeJson.Ports;
    map<json> portsMap = check portsData.ensureType();
    json[] portsList = [];
    foreach [string, json] [_, value] in portsMap.entries() {
        portsList.push(value);
    }

    json estadoOntPonJson = {
        "Ports": {
            "Port": portsList
        }
    };

    return estadoOntPonJson;
}

# Função responsável por adaptar os dados para a operação GPON_ESTADO_ONT.
#
# + completeJson - JSON completo com todos os parâmetros de busca oriundos da requisição  
# + schedulerData - JSON com os dados de SCHEDULER da operação  
# + macAddressData - JSON com os dados de MACADDRESS da operação
# + vendor - string do vendor da requisição
# + return - JSON do searchParameters adaptado ou mensagem de erro ao buscar algum dado mandatório inexistente
public isolated function configureGponEstadoOnt(json completeJson, json schedulerData, json macAddressData, string vendor) returns json|error {
    json searchParametersCompleto = completeJson;
    if schedulerData != {} {
        searchParametersCompleto = check createScheduler(searchParametersCompleto, schedulerData, vendor);
    }
    if macAddressData != {} {
        searchParametersCompleto = check createMacAddress(searchParametersCompleto, macAddressData);
    }
    return searchParametersCompleto;
}

# Função responsável por criar a lista de SCHEDULER presentes na operação.
#
# + completeJson - JSON completo com todos os parâmetros da operação  
# + schedulerData - JSON com os dados de SCHEDULER da operação
# + vendor - string do vendor da requisição
# + return - JSON com os dados de SCHEDULER adaptados
public isolated function createScheduler(json completeJson, json schedulerData, string vendor) returns json|error {
    json[] scheduler = [];
    match vendor.toLowerAscii() {
        "alcatel" => {
            scheduler = [
                    schedulerData.SCHEDULER is error ? "" : check schedulerData.SCHEDULER,
                ""
            ];
        }
        "huawei" => {
            scheduler = [
                    schedulerData.SCHEDULER\.1 is error ? "" : check schedulerData.SCHEDULER\.1,
                    schedulerData.SCHEDULER is error ? "" : check schedulerData.SCHEDULER
            ];
        }
        _ => {
            scheduler = [
                    schedulerData.SCHEDULER\.1 is error ? "" : check schedulerData.SCHEDULER\.1,
                    schedulerData.SCHEDULER\.2 is error ? "" : check schedulerData.SCHEDULER\.2
            ];
        }
    }
    json schedulerObj = {SCHEDULER: scheduler};
    return check completeJson.mergeJson(schedulerObj);
}

# Função responsável por criar a lista de MACADDRESS presentes na operação.
#
# + completeJson - JSON completo com todos os parâmetros da operação  
# + macAdressData - JSON com os dados de MACADDRESS da operação
# + return - JSON com os dados de MACADDRESS adaptados
public isolated function createMacAddress(json completeJson, json macAdressData) returns json|error {
    json macAddressVlan = {
        "VLAN": {
            "IPTV": {
                "MACADDRESS": macAdressData.MACADDRESS1 is error ? "" : check macAdressData.MACADDRESS1
            },
            "HSI": {
                "MACADDRESS": macAdressData.MACADDRESS2 is error ? "" : check macAdressData.MACADDRESS2
            }
        }
    };

    return check completeJson.mergeJson(macAddressVlan);
}

# Função responsável por adaptar os parâmetros com números em suas chaves em listas.
#
# + withNumbers - JSON com todos os objetos que contém números em suas chaves
# + keysWithNumbers - Lista de chaves que apresentam números 
# + return - JSON com os valores adaptados para listas
public isolated function adaptNumberJson(json withNumbers, string[] keysWithNumbers) returns json|error {

    string[] keyUpToFirstNumberList = [];
    json withNumbersAdapted = {};
    foreach string firstKey in keysWithNumbers {
        string[] keySplitList = regex:split(firstKey, "\\.");
        string keyUpToFirstNumber = "";
        foreach string keySplit in keySplitList {
            keyUpToFirstNumber = keyUpToFirstNumber.concat(keySplit);
            if int:fromString(keySplit) !is error {
                if keyUpToFirstNumberList.indexOf(keyUpToFirstNumber) == () {
                    keyUpToFirstNumberList.push(keyUpToFirstNumber);
                }
                break;
            }
            keyUpToFirstNumber = keyUpToFirstNumber.concat(".");
        }
    }

    foreach int i in 0 ... keyUpToFirstNumberList.length() - 1 {
        string objectNumberString = "";
        map<json> objectNumberMap = check withNumbers.ensureType();
        string completeKey = keyUpToFirstNumberList[i];

        string[] attributes = regex:split(completeKey, "\\.");

        foreach int j in 0 ... attributes.length() - 1 {
            string attribute = attributes[j];

            json data = objectNumberMap.get(attribute);

            map<json>|error nextDataMap = data.ensureType();
            if nextDataMap is error {

                json objectJson = {[attribute] : data};
                objectNumberString = objectNumberString.concat(objectJson.toString());
                continue;
            }
            objectNumberMap = check data.ensureType();
            if int:fromString(attribute) !is error {

                continue;
            }
            objectNumberString = objectNumberString.concat("{ \"", attribute, "\" :");
            if int:fromString(attributes[j + 1]) !is error {

                objectNumberString = objectNumberString.concat("[");
                string[] nextKeys = nextDataMap.keys();
                nextKeys = nextKeys.sort();

                foreach string nextKey in nextKeys {
                    json nextJson = nextDataMap.get(nextKey);
                    string[] nextIterationKeyList = [];
                    foreach string oldKey in keysWithNumbers {

                        int index = <int>oldKey.indexOf(attribute + ".");

                        int nextIndex = index + attribute.length() + 3;
                        if nextIndex >= oldKey.length() {

                        } else {
                            string nextIterationKey = oldKey.substring(nextIndex, <int>oldKey.lastIndexOf("."));

                            boolean test = false;
                            foreach string item in nextIterationKeyList {
                                if item.includes(nextIterationKey) {
                                    test = true;
                                }
                            }
                            if test {

                            } else {

                                nextIterationKeyList.push(oldKey.substring(nextIndex));
                            }
                        }
                    }

                    if nextIterationKeyList.length() != 0 {

                        nextJson = check adaptNumberJson(nextJson, nextIterationKeyList);
                    }
                    // É AQUI

                    objectNumberString = objectNumberString.concat(nextJson.toString());
                    if nextKeys.indexOf(nextKey) == nextKeys.length() - 1 {
                        continue;
                    }
                    objectNumberString = objectNumberString.concat(",");
                }
                objectNumberString = objectNumberString.concat("]");
                foreach string _ in keysWithNumbers {
                    objectNumberString = objectNumberString.concat("}");
                }

                withNumbersAdapted = check objectNumberString.fromJsonString();

            }
        }

    }

    return withNumbersAdapted;
}
