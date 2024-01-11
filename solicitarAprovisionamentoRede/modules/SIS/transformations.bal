import ballerina/regex;
import ballerina/log;
import ballerina/os;



# Função responsável pela tradução da prioridade da operação enviada pelo SOM.
#
# + operation - String obtida no request enviado pelo SOM.
# + return - Inteiro utilizado para definir a prioridade da operação ao SIS.
public isolated function definePriority(string operation) returns int{
   if regex:matches(operation, "ASSOCIAR_ONT_APC"){
        return 7;
   }
   else if regex:matches(operation, "^DESBLOQUEAR_.*"){
        return 5; 
   }
    else if regex:matches(operation,  "MODIFICAR_HSI_NASS"){
        return 3;
   }
    else if regex:matches(operation, "^BLOQUEAR_.*"){
        return 1;
   }
   else{
        return 1;
   }
}

# Função responsável pela formatação dos dados recebidos por parte do SOM para o formato esperado pelo SIS 
# VTal.
#
# + data - JSON com os dados extraidos do request enviado pelo SOM.
# + return - JSON formatado para o envio do request ao SIS ou erro caso ocorra algum problema na formatação.
public isolated function transformRequestSISVTal(json data) returns json|error {
    string operation = <string> check data.operation;
    string urlSISCallback = os:getEnv("INTNOSSIS-SIS-CALLBACK");
    int priority = definePriority(operation);
    string systemId = data.originSystem == "" ? check data.correlationId : check data.originSystem;
    json parameters = check data.parameters;
    json requestSISVTal = {
        "systemId": systemId,
        "externalId": check data.correlationId,
        "priority": priority,
        "timeToLive": 120000,
        "endpointReply": urlSISCallback,
        "serviceElements": [
            {
                "code": operation,
                "parameters": [
                    {
                        "ACESSO_ASSET_ID": parameters.acessoGPON.value is error? "":check parameters.acessoGPON.value,
                        "ACESSO_ASSET_ID_OLD": parameters.acessoGPON.originalValue is error? "":check  parameters.acessoGPON.originalValue,
                        "C_VLAN_HSI": parameters.CVLAN1.value is error? "":check parameters.CVLAN1.value,
                        "C_VLAN_HSI_OLD": parameters.CVLAN1.originalValue is error? "":check parameters.CVLAN1.originalValue,
                        "LINE_ID_HSI_OLD": parameters.LINEID1.originalValue is error? "":check parameters.LINEID1.originalValue,
                        "LINE_ID_HSI": parameters.LINEID1.value is error? "":check parameters.LINEID1.value,
                        "LINE_ID_IPTV_VOIP_OLD": parameters.C_VLAN_IPTV.value is error? "":check parameters.C_VLAN_IPTV.originalValue,
                        "LINE_ID_IPTV_VOIP": parameters.C_VLAN_IPTV.value is error? "":check parameters.C_VLAN_IPTV.value,
                        "GALC": parameters.OLTGALC.value is error? "":check parameters.OLTGALC.value,
                        "OLT_PORT": parameters.OLTPORT.value is error? "":check parameters.OLTPORT.value,
                        "RACK": parameters.OLTRACK.value is error? "":check parameters.OLTRACK.value,
                        "OLT_SHELF": parameters.OLTSHELF.value is error? "":check parameters.OLTSHELF.value,
                        "OLT_SLOT": parameters.OLTSLOT.value is error? "":check parameters.OLTSLOT.value,
                        "S_VLAN_HSI": parameters.SVLAN1.value is error? "":check parameters.SVLAN1.value,
                        "S_VLAN_HSI_OLD": parameters.SVLAN1.originalValue is error? "":check parameters.SVLAN1.originalValue,
                        "CDOI_SPLITER_PORT": parameters.splitterPort.value is error? "":check parameters.splitterPort.value,
                        "NUMERO_OS": parameters.numeroOS.value is error? "":check parameters.numeroOS.value,
                        "VELOCIDADE_DOWN": parameters.velocidadeDownload.value is error? "":check parameters.velocidadeDownload.value,
                        "VELOCIDADE_DOWN_OLD": parameters.velocidadeDownload.originalValue is error? "":check parameters.velocidadeDownload.originalValue,
                        "VELOCIDADE_UP": parameters.velocidadeUpload.value is error? "":check parameters.velocidadeUpload.value,
                        "VELOCIDADE_UP_OLD": parameters.velocidadeUpload.originalValue is error? "":check parameters.velocidadeUpload.originalValue,
                        "NUMERO_SERIE_ONT": parameters.numeroSerieONT.value is error? "":check parameters.numeroSerieONT.value,
                        "SERVICE_TAG": parameters.serviceTag.value is error? "":check parameters.serviceTag.value,
                        "FABRICANTE_OLT": parameters.FABRICANTE.value is error? "": check parameters.FABRICANTE.value,
                        "VENDOR_ONT": parameters.fornecedorCPE.value is error? "":check parameters.fornecedorCPE.value,
                        "MODEL_ONT": parameters.modeloCPE.value is error? "":check parameters.modeloCPE.value,
                        "COMPANYID": parameters.companyID.value is error? "":check parameters.companyID.value
                    }
                ]
            }
        ]
    };
    log:printInfo("Request a ser entregue ao SIS VTAL", request = requestSISVTal);
    return requestSISVTal;
}