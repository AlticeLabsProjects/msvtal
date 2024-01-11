import retornarInformacoesRede.NetQ;
import retornarInformacoesRede.FFOne;
import retornarInformacoesRede.SIS;
import ballerina/log;


# Função responsável por realizar a orquestração do response recebido do FFOne.
#
# + FFOneRequest - JSON recebido do FFOne
# + return - Erro em caso de falha na postagem da fila do SOM.
public isolated function requestOrchestrationFFOne(json FFOneRequest) returns error?{
    json|error requestNetQ = FFOne:transformFFOneNetQRequest(FFOneRequest);
    if requestNetQ is error{
        log:printError("Erro ao realizar a transformação do request ao SOM");
        return requestNetQ;
    }

    FFOne:NetqPathRequest netqPath = check FFOne:adaptNetqPath(FFOneRequest);
    json|error? responseNetQ = NetQ:sendRequestNetQ(requestNetQ, netqPath.urlNetq, netqPath.uriNetq);
    if responseNetQ is error{
        log:printError("Erro ao postar a mensagem na fila do SOM");
        return responseNetQ;
    }
    
}


# Função responsável por realizar a orquestração do response recebido do SIS.
#
# + SISRequest - JSON recebido do SIS
# + return - Erro em caso de falha na postagem da fila do SOM.
public isolated function requestOrchestrationSIS(json SISRequest) returns error?{
    json|error requestNetQ = SIS:transformSISVTalNetRequest(SISRequest);
    if requestNetQ is error{
        log:printError("Erro ao realizar a transformação do request ao SOM");
        return requestNetQ;
    }
    log:printInfo("resposta a ser enviada:");
    log:printInfo(requestNetQ.toString());
    
    SIS:NetqPathRequest netqPath = check SIS:adaptNetqPath(SISRequest);
    json|error? responseNetQ = NetQ:sendRequestNetQ(requestNetQ, netqPath.urlNetq, netqPath.uriNetq);

    if responseNetQ is error{
        log:printError("Erro ao postar a mensagem na fila do SOM",responseNetQ);
        return responseNetQ;
    }
    log:printInfo(responseNetQ.toString());
}

