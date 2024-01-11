import ballerina/log;
import ballerina/io;

# Função responsável pela obtenção dos dados a partir do XML recebido do SOM
#
# + SOMRequestXml - Recebe o XML obtido a partir da fila JMS em que o SOM posta a mensagem.
# + return - Retorna um JSON com os dados necessários para a orquestração do código.
public isolated function getDataFromSOMXml(xml SOMRequestXml) returns json|error {
    log:printInfo("Ajustando o request recebido do SOM.");
    //io:println(((SOMRequestXml/*).<sendDate>).elements());
    xmlns "FTTHActivationInterface" as FTTHActivationInterface;
    xml solicitarInformacoesRede = SOMRequestXml/**/<FTTHActivationInterface:request>;
    io:println(solicitarInformacoesRede);

    json SOMResponse = {
        "correlationId": ((solicitarInformacoesRede/*).<correlationId>).data(),
        "messageId": ((solicitarInformacoesRede/*).<messageId>).data(),
        "sendDate": ((solicitarInformacoesRede/*).<sendDate>).data(),
        "operation": ((solicitarInformacoesRede/*).<operation>).data(),
        "originSystem":((solicitarInformacoesRede/*).<originSystem>).data()
    };
    xml attributeListData = ((solicitarInformacoesRede/*).<attributeList>)/<*>;
    json parameters = {};
    foreach var item in attributeListData {
        string name2 = (item/**/<name>).data();
        string value = (item/**/<value>).data();
        string|error originalValue = (item/**/<originalValue>).data();
        if originalValue is error{
            originalValue = "";
        }

        parameters = check parameters.mergeJson({
            [name2] : {"value": value, "originalValue":check originalValue}
        });
    }
    SOMResponse = check SOMResponse.mergeJson({
        "parameters" : parameters
    });
    log:printInfo("Request do SOM ajustado.");
    log:printInfo(SOMResponse.toString());
    return SOMResponse;
}