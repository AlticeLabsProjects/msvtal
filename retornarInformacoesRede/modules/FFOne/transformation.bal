import ballerina/log;
import ballerina/mime;
import ballerina/regex;

public type NetqPathRequest record{
    string urlNetq;
    string uriNetq;
};
# Função responsável pelo ajuste do response assincrono recebido por parte do FFOne para o
# formato esperado pelo NetQ.
#
# + jsonResponseFFOne - JSON recebido como resposta assincrona do FFOne.
# + return - Retorna JSON formatado para o envio ao NetQ.
public isolated function transformFFOneNetQRequest(json jsonResponseFFOne) returns json|error {
    log:printInfo("Ajustando resposta assincrona fornecida pelo FFOne");
    json data = check adaptFFOneAsyncResponse(jsonResponseFFOne);
    string networkResponse = check createSearchParameters(data) ?: "";
    json requestNetQ = {
        "netqId": check data.netqId,
        "sisId": check data.sisId,
        "operation": check data.operation,
        "status": {
            "code": check data.code,
            "description": check data.description
        },
        "response": {networkResponse}
    };
    
    log:printInfo(requestNetQ.toString());
    return requestNetQ;
}

# Função responsável por criar o objeto searchParameters a ser enviado ao netq.
#
# + data - JSON com os dados enviados pelo FFOne 
# + return - string que representa o campo networkResponse a ser enviado
public isolated function createSearchParameters(json data) returns string|error? {
    string ontAdminState = data.ontAdminState is error ? "" : check data.ontAdminState;
    ontAdminState = ontAdminState.toLowerAscii();
    string portaEthernet = data.ethPort is error ? "" : check data.ethPort;
    portaEthernet = regex:replace(portaEthernet, "\"\"","\"");

    json searchParameters = {
        "SearchParameters": {
            "COMPANY_ID_OLT": check data.companyId,
            "ESTADO_OPERACIONAL": {
                "UNI": data.uniOpcState is error ? "" : check data.uniOpcState,
                "ONT": data.ontOpcState is error ? "" : check data.ontOpcState,
                "VEIP": data.veipOpcState is error ? "" : check data.veipOpcState
            },
            "PERFIL_UPSTREAM": {
                "SINAL": data.sinalUpPrf is error ? "" : check data.sinalUpPrf,
                "VOZ": data.vozUpPrf is error ? "" : check data.vozUpPrf,
                "VIDEO": data.videoUpPrf is error ? "" : check data.videoUpPrf,
                "HSI": data.hsiUpPrf is error ? "" : check data.hsiUpPrf
            },
            "VLAN": {
                "IPTV": {
                    "FABRICANTE_ROUTER": data.vendorRouterHsiVlan is error ? "" : check data.vendorRouterHsiVlan,
                    "CVLAN": data.cvlanHsiVlan is error ? "" : check data.cvlanHsiVlan,
                    "SVLAN": data.svlanIptvVlan is error ? "" : check data.svlanIptvVlan,
                    "MACADDRESS": data.macAddr1 is error ? "" : check data.macAddr1
                },
                "HSI": {
                    "FABRICANTE_ROUTER": data.vendorRouterHsiVlan is error ? "" : check data.vendorRouterHsiVlan,
                    "CVLAN": data.cvlanHsiVlan is error ? "" : check data.cvlanHsiVlan,
                    "SVLAN": data.svlanHsiVlan is error ? "" : check data.svlanHsiVlan,
                    "MACADDRESS": data.macAddr2 is error ? "" : check data.macAddr2
                }
            },
            "ONTID": data.onuId is error ? "" : check data.onuId,
            "CPU_MEMORIA": data.cpuMem is error ? "" : check data.cpuMem,
            "PORTA_ETHERNET": portaEthernet,
            "TEMPERATURA": data.temperature is error ? "" : check data.temperature,
            "LINE_ID": data.lineId is error ? "" : check data.lineId,
            "ONT": data.onuId is error ? "" : check data.onuId,
            "FIRMWARE_ONT": data.ontFirmware is error ? "" : check data.ontFirmware,
            "MACADDRESS1": data.macAddr1 is error ? "" : check data.macAddr1,
            "MACADDRESS2": data.macAddr2 is error ? "" : check data.macAddr2,
            "SCHEDULER": [data.sch1 is error ? "" : check data.sch1, data.sch2 is error ? "" : check data.sch2],
            "SLOT": data.ontSlot is error ? "" : check data.ontSlot,
            "NEGOCIACAO": data.negotiation is error ? "" : check data.negotiation,
            "ESTADO_ADMINISTRATIVO": {
                "ONT": ontAdminState,
                "IPTV": data.iptvAdminState is error ? "" : check data.iptvAdminState,
                "VEIP": data.veipAdminState is error ? "" : check data.veipAdminState,
                "HSI": data.hsiAdminState is error ? "" : check data.hsiAdminState
            },
            "VERSAO_HARDWARE": data.versionHW is error ? "" : check data.versionHW,
            "MOTIVO_QUEDA": data.downReason is error ? "" : check data.downReason,
            "SERVICE_TAG": "",
            "NUMERO_SERIE": data.ontSerialNumber is error ? "" : check data.ontSerialNumber,
            "PID": "",
            "MODEL": data.oltModel is error ? "" : check data.oltModel,
            "OID": "",
            "PORTA": data.oltPort is error ? "" : check data.oltPort,
            "PON": "",
            "SW_PLANEJADO": data.plannedSW is error ? "" : check data.plannedSW,
            "ONT_PORT": data.ontPort is error ? "" : check data.ontPort,
            "RACK": data.oltRack is error ? "" : check data.oltRack,
            "ONT_SLOT": data.ontSlot is error ? "" : check data.ontSlot,
            "PERFIL_DOWNSTREAM": {
                "SINAL": data.sinalDownPrf is error ? "" : check data.sinalDownPrf,
                "VOZ": data.vozDownPrf is error ? "" : check data.vozDownPrf,
                "VIDEO": data.videoDownPrf is error ? "" : check data.videoDownPrf,
                "HSI": data.hsiDownPrf is error ? "" : check data.hsiDownPrf
            },
            "MODELO": data.ontModel is error ? "" : check data.ontModel,
            "MODO_DUPLEX": data.duplexMode is error ? "" : check data.duplexMode,
            "VERSION": data.oltVersion is error ? "" : check data.oltVersion,
            "CONFIG_STATE": data.confState is error ? "" : check data.confState,
            "SHELF": data.oltShelf is error ? "" : check data.oltShelf,
            "VENDOR": data.oltVendor is error ? "" : check data.oltVendor,
            "VELOCIDADE_WAN": data.wanSpeed is error ? "" : check data.wanSpeed,
            "ASSN1": data.ASSN1 is error ? "" : check data.ASSN1,
            "ASSN2": data.ASSN2 is error ? "" : check data.ASSN2,
            "OLT_NAME": data.olt is error ? "" : check data.olt
        }
    };
    return searchParameters.toString();
}

# Função responsável por passar as informações recebidas do diagnostico para a codificação Base64 
# e extrair os dados necessários para o mapeamento.
#
# + responseBody - JSON com os dados obtidos a partir da resposta do SIS FFOne.
# + return - return value description
public isolated function adaptFFOneAsyncResponse(json responseBody) returns json|error {

    string? state = check responseBody?.event?.serviceOrder?.state;
    string code = "";
    string description = "";

    if state is string && state.trim() == "Completed" {
        code = "Success";
        description = "Executado com sucesso.";
    } else {
        code = "Falha";
        description = "Executado com falha.";
    }

    string id = check responseBody?.event?.serviceOrder?.externalId;
    int? firstIndex = id.indexOf(":");
    int? endIndex = id.lastIndexOf(":");

    if firstIndex is int && endIndex is int{
        id = id.substring(firstIndex + 1, endIndex);
    }

    string encodedString = check (check mime:base64Encode(responseBody.toJsonString())).ensureType();

    json adaptFFOneResponse = {
        netqId: id,
        sisId: id,
        operation: "GPON_ESTADO_ONT",
        code: code,
        description: description,
        log: encodedString
    };

    json vals = check responseBody?.event?.serviceOrder?.orderItem;
    json[] arr = check vals.ensureType();

    // Começo da preparação dos SearchParameters
    foreach json item in arr {
        json characteristicVals = check item?.outputEntities?.'service?.serviceCharacteristic;
        json[] characteristicValsArr = check characteristicVals.ensureType();
        string[] names = [];

        foreach json characteristic in characteristicValsArr {

            string nameCha = check characteristic?.name;
            string valueCha = check characteristic?.value;

            if (names.indexOf(nameCha) == ()) {
                adaptFFOneResponse = check adaptFFOneResponse.mergeJson({
                    [nameCha] : valueCha
                });
                names.push(nameCha);
            }

        }

        json otherCharacteristicVals = check item?.'service?.serviceCharacteristic;
        json[] otherCharacteristicValsArr = check otherCharacteristicVals.ensureType();
        foreach json otherCharacteristic in otherCharacteristicValsArr {

            string nameCha = check otherCharacteristic?.name;
            string valueCha = check otherCharacteristic?.value;

            if (names.indexOf(nameCha) == ()) {
                adaptFFOneResponse = check adaptFFOneResponse.mergeJson({
                    [nameCha] : valueCha
                });
                names.push(nameCha);
            }
        }
    }

    return adaptFFOneResponse;
}

public isolated function adaptNetqPath(json request) returns NetqPathRequest|error{
    json[] relatedParty = <json[]> check request.event.serviceOrder.relatedParty; 
    json property = check relatedParty[0].property;
    string urlCompleta = "";
    
    foreach json item in <json[]> property {
        if item.name == "endpointReply"{
            urlCompleta = check item.value;
        }
    }
    
    if urlCompleta == "" {
        log:printError("Erro ao encontrar a url na request recebida");
        return error("Erro ao encontrar a url na request recebida");
    }
    
    int initIndex = <int> urlCompleta.lastIndexOf(":");
    int endIndex = <int> urlCompleta.indexOf("/", initIndex);
    string url = urlCompleta.substring(0, endIndex);
    string uri = urlCompleta.substring(endIndex);
    NetqPathRequest netqPath = {urlNetq: url, uriNetq: uri};
    log:printInfo("Url a ser chamada: " + netqPath.toString());
    return netqPath;
}