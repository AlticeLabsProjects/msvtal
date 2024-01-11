import ballerina/log;
import ballerina/uuid;
import ballerina/os;


# Função responsável por realizar o mapeamento das informações vindas do NetQ para o formato
# esperado pelo FFOne.
#
# + data - JSON com os dados extraidos do XML enviado pelo NetQ.
# + return - JSON com a estrutura esperada pelo FFOne.
public isolated function transformFFOneRequest(json data) returns json|error {
    string urlFFOneCallback = os:getEnv("INTNOSSIS-FFONE-DIAG-CALLBACK");
    json parameters = check data.parameters;
    string serviceId = <string>check parameters.OLT_NAME + ":" +<string>check parameters.RACK +  <string>check parameters.SHELF + <string>check parameters.SLOT + <string>check parameters.PON + <string>check parameters.ONTID;
    string externalId = "Oi:" + <string> check data.idNetq + ":" + uuid:createType4AsString();
    log:printInfo("Realizando o mapeamento do request para o FFOne", id = check data.idNetq);
    json requestFFone = 
    {
        "externalId": externalId,
        "category": "ACTIVATOR.ORDER",
        "requesterCallback": urlFFOneCallback,
        "relatedParty": [
            {
            "role": "sourceSystem",
            "property": [
                {
                "name": "systemId",
                "value": "NetQ"
                },
                {
                "name": "correlationId",
                "value": check data.idNetq
                },
                {
                "name": "endpointReply",
                "value": check data.url
                }
            ]
            }
        ],
        "orderItem": [
            {
            "id": "sdiagnostico",
            "action": "statusOnt",
            "serviceSpecification": {
                "id": "RFS.GPONACCESS"
            },
            "service": {
                "id": serviceId,
                "category": "RFS",
                "serviceCharacteristic": [
                {
                    "name": "lineId",
                    "value": parameters.LINE_ID is error? check parameters.LINEID : check parameters.LINE_ID
                },
                {
                    "name": "olt",
                    "value": parameters.OLT_NAME is error? "" : check parameters.OLT_NAME
                },
                {
                    "name": "oltRack",
                    "value": parameters.RACK is error? "" : check parameters.RACK
                },
                {
                    "name": "oltShelf",
                    "value": parameters.SHELF is error? "" : check parameters.SHELF
                },
                {
                    "name": "oltSlot",
                    "value": parameters.SLOT is error? "" : check parameters.SLOT
                },
                {
                    "name": "oltPort",
                    "value": parameters.PON is error? "" : check parameters.PON
                },
                {
                    "name": "onuId",
                    "value": parameters.ONTID is error? "" : check parameters.ONTID
                },
                {
                    "name": "oltVersion",
					"value": parameters.VERSION is error? "" : check parameters.VERSION
                },
                {
                    "name": "oltVendor",
                    "value": parameters.VENDOR is error? "" : check parameters.VENDOR
                },
                {
                    "name": "oltModel",
                    "value": parameters.MODEL is error? "" : check parameters.MODEL
                },
                {
                    "name": "companyId",
                    "value": parameters.COMPANY_ID is error? "" : check parameters.COMPANY_ID
                }
                ]
            }
            }
        ]
    };
    return requestFFone;
}


