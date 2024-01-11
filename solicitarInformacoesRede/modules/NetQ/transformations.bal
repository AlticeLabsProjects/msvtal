import ballerina/log;

# Função responsável por retornar o xml correto para a requisição do NetQ.
#
# + responseEnv - Resposta enviada pelo ambiente da requisição
# + return - Retorna xml de erro/sucesso a ser enviado para o NetQ
public isolated function transformResponseNetq(json|error responseEnv) returns xml|error {
    xml errorResponse = xml
        `<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
            <soapenv:Header/>
            <soapenv:Body>
                <tns:SolicitarInformacoesRedeResponse xmlns:tns="http://www.oi.net.br/GestaoRecurso/solicitarInformacoesRede/v1">
                <tns:code>1111</tns:code>
                <tns:reason>FALHA</tns:reason>
                <tns:detail>FALHA</tns:detail>
                </tns:SolicitarInformacoesRedeResponse>
            </soapenv:Body>
        </soapenv:Envelope>`;
    if responseEnv is error {
        log:printError("Error ao fazer conexão com o FFOne", responseEnv);
        return errorResponse;
    }

    log:printInfo("Got response");
    log:printInfo(responseEnv.toString());
    string? failed = check responseEnv?.message;
    if failed is string {
        log:printError("Ocorreu uma falha ao criar a ordem de serviço. Mensagem - " + failed);
        return errorResponse;
    }

    xml response = xml
    `<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
            <soapenv:Header/>
            <soapenv:Body>
                <tns:SolicitarInformacoesRedeResponse xmlns:tns="http://www.oi.net.br/GestaoRecurso/solicitarInformacoesRede/v1">
                <tns:code>0000</tns:code>
                <tns:reason>SUCESSO</tns:reason>
                <tns:detail>SUCESSO</tns:detail>
                </tns:SolicitarInformacoesRedeResponse>
            </soapenv:Body>
        </soapenv:Envelope>`;

    return response;
}
