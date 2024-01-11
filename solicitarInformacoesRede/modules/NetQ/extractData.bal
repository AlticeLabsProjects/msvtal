import ballerina/log;
//import ballerina/lang.regexp;
import ballerina/io;

# Função responsável pela extração e organização do request recebido do NETQ.
#
# + NETQResponseXml - parameter description
# + return - return value description
public isolated function getDataFromNETQXml(xml NETQResponseXml) returns json|error {
    xmlns "http://www.oi.net.br/GestaoRecurso/solicitarInformacoesRede/v1" as v11;
    xmlns "http://www.oi.net.br/INFRA/SOAFW/SharedResources/Messaging/v1" as v1;
    log:printInfo("Extraindo os dados do NETQ");
    xml solicitarInformacoesRede = NETQResponseXml/**/<v11:SolicitarInformacoesRedeRequest>;
    json NETQResponseJson = {
        "transactionId": (solicitarInformacoesRede/**/<v1:TransactionId>).data(),
        "appId": ((solicitarInformacoesRede/**/<v1:AppId>)).data(),
        "idNetq": ((solicitarInformacoesRede/**/<v11:idNetq>)).data(),
        "prioridade": ((solicitarInformacoesRede/**/<v11:prioridade>)).data(),
        "operation":  ((solicitarInformacoesRede/**/<v11:operation>)).data(),
        "url": ((solicitarInformacoesRede/**/<v11:url>)).data(),
        "timeoutInSeconds": ((solicitarInformacoesRede/**/<v11:timeoutInSeconds>)).data()
    };
    string attributeListstring =((solicitarInformacoesRede/**/<v11:request>)).data();
    log:printInfo(attributeListstring);
    xml attributeListstringXML = check xml:fromString(attributeListstring);
    json parameters = {};
    foreach var item in attributeListstringXML/<*> {
        log:printInfo(item.toString());
        json attributesElement = item.getAttributes();
        string name = check attributesElement.name;
        string value = check attributesElement.value;
        parameters = check parameters.mergeJson({[name]:value} );
    }    
    NETQResponseJson = check NETQResponseJson.mergeJson({
        "parameters": parameters
    });
    log:printInfo("Dados extraidos.");
    io:println(NETQResponseJson);
    return NETQResponseJson;
}
