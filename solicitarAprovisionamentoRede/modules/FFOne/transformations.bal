import ballerina/uuid;
import ballerina/os;
import ballerina/log;
import ballerina/regex;


# Função responsável pela formatação dos dados enviados pelo SOM e já extraídos do XML para o envio ao 
# FOne.
#
# + data - JSON com os dados extraidos do XML enviado pelo SOM.
# + return - JSON formatado para o envio ao FFOne ou erro gerado no processo.
public isolated function transformRequestFFOne(json data) returns json|error {
    string urlFFOneCallback = os:getEnv("INTNOSSIS-FFONE-CALLBACK");
    json parameters = check data.parameters;
    string lineId1 = <string> check parameters.LINEID1.value;
    string onuId = regex:split(lineId1, "/")[4];
    string systemId = data.originSystem == "" ? "SOM" : check data.originSystem;
    string serviceId = <string>check parameters.OLTGALC.value + ":" + <string>check parameters.OLTRACK.value + "-" + <string>check parameters.OLTSHELF.value + "-" + <string>check parameters.OLTSLOT.value + "-" + <string>check parameters.OLTPORT.value + "-" + <string> onuId;
    string externalId = (parameters.companyID.value is error? systemId : <string>check parameters.companyID.value) + ":" + <string> check data.correlationId + ":" + uuid:createType4AsString();
    string|error productClass = parameters.productClass.value.ensureType();
    if productClass is error{
        productClass = "Whitelabel";
    }
    json FFOneRequest = {
        //Dado de companyId nao veio no SOM
        "externalId": externalId,
        "category": "ACTIVATOR.ORDER",
        "requesterCallback": urlFFOneCallback,
        "relatedParty": [
            {
            "role": "sourceSystem",
            "property": [
                {
                //O SOM é uma constante? Dado nao consta no xml de entrada (data.originSystem nunca existe)
                "name": "systemId",
                "value": systemId
                },
                {
                "name": "correlationId",
                "value": check data.correlationId
                },
                {
                "name": "endpointReply",
                "value":urlFFOneCallback
                }
            ]
            }
        ],
        "orderItem": [
            {
            "id": "sprovisao",
            "action": "modifyOnt",
            "serviceSpecification": {
                "id": "RFS.GPONACCESS"
            },
            "service": {
                "id": serviceId,
                "category": "RFS",
                "serviceCharacteristic": [
                {
                    "name": "accessAssetId",
                    "value": parameters.acessoGPON.value is error? "":check parameters.acessoGPON.value
                },
                {
                    "name": "accessAssetIdOld",
                    "value": parameters.acessoGPON.originalValue is error? "":check parameters.acessoGPON.originalValue
                },
                {
                    "name": "companyId",
                    "value": parameters.companyID.value is error? "":check parameters.companyID.value
                },
                {
                    "name": "nbrOs",
                    "value": parameters.numeroOS.value is error? "":check parameters.numeroOS.value
                },
                {
                    "name": "prodClass",
                    "value": productClass is error? "": productClass
                },
                {
                    "name": "serviceTag",
                    "value": parameters.serviceTag.value is error? "":check parameters.serviceTag.value
                },
                {
                    "name": "lineIdHsi",
                    "value": parameters.LINEID1.value is error? "":check parameters.LINEID1.value
                },
                {
                    "name": "lineIdHsiOld",
                    "value": parameters.LINEID1.originalValue is error? "":check parameters.LINEID1.originalValue
                },
                {
                    "name": "lineIdIptvVoipOld",
                    "value": parameters.C_VLAN_IPTV.value is error? "":check parameters.C_VLAN_IPTV.value
                },
                {
                    "name": "lineIdIptvVoip",
                    "value": parameters.C_VLAN_IPTV.originalValue is error? "": check parameters.C_VLAN_IPTV.originalValue 
                },
                {
                    "name": "olt",
                    "value": parameters.OLTGALC.value is error? "":check parameters.OLTGALC.value
                },
                {
                    "name": "oltRack",
                    "value": parameters.OLTRACK.value is error? "":check parameters.OLTRACK.value
                },
                {
                    "name": "oltShelf",
                    "value": parameters.OLTSHELF.value is error? "":check parameters.OLTSHELF.value
                },
                {
                    "name": "oltSlot",
                    "value": parameters.OLTSLOT.value is error? "":check parameters.OLTSLOT.value
                },
                {
                    "name": "oltPort",
                    "value": parameters.OLTPORT.value is error? "":check parameters.OLTPORT.value
                },
                {
                    "name": "cdoiSpliterPort",
                    "value": parameters.splitterPort.value is error? "":check parameters.splitterPort.value
                },
                {
                    "name": "oltVendor",
                    "value": parameters.OLTVendor.value is error? "":check parameters.OLTVendor.value
                },
                {
                    "name": "speedDown",
                    "value": parameters.velocidadeDownload.value is error? "":check parameters.velocidadeDownload.value
                },
                {
                    "name": "speedDownOld",
                    "value": parameters.velocidadeDownload.originalValue is error? "":check parameters.velocidadeDownload.originalValue
                },
                {
                    "name": "speedUp",
                    "value": parameters.velocidadeUpload.value is error? "":check parameters.velocidadeUpload.value
                },
                {
                    "name": "speedUpOld",
                    "value": parameters.velocidadeUpload.originalValue is error? "":check parameters.velocidadeUpload.originalValue
                },
                {
                    "name": "cVlanHsi",
                    "value": parameters.CVLAN1.value is error? "":check parameters.CVLAN1.value
                },
                {
                    "name": "cVlanHsiOld",
                    "value": parameters.CVLAN1.originalValue is error? "":check parameters.CVLAN1.originalValue
                },
                {
                    "name": "sVlanHsi",
                    "value": parameters.SVLAN1.value is error? "":check parameters.SVLAN1.value
                },
                {
                    "name": "sVlanHsiOld",
                    "value": parameters.SVLAN1.originalValue is error? "":check parameters.SVLAN1.originalValue
                },
                {
                    "name": "ontVendor",
                    "value": parameters.ONTVendor.value is error? "":check parameters.ONTVendor.value
                },
                {
                    "name": "ontModel",
                    "value": parameters.modeloCPE.value is error? "":check parameters.modeloCPE.value
                },
                {
                    "name": "ontSerialNumber",
                    "value": parameters.numeroSerieONT.value is error? "":check parameters.numeroSerieONT.value
                }
                ]
            }
            }
        ]
    };
    log:printInfo("Request a ser enviada ao FFOne", request = FFOneRequest);
    return  FFOneRequest;
}