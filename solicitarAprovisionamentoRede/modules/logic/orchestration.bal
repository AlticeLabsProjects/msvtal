import ballerina/log;
import ballerinax/oracledb;
import ballerina/sql;
import ballerinax/oracledb.driver as _;
import solicitarAprovisionamentoRede.SOM;
import solicitarAprovisionamentoRede.FFOne;
import solicitarAprovisionamentoRede.SIS;
import ballerina/regex;
// import ballerina/os;


# Record criado para representar campo obtido a partir da query que será realizada no banco para a 
# definição de qual será o sistema alvo do roteamento.
#
# + system_target - String com os possiveis valores: SIS V2, SIS VTAL e FFONE.
type QueryResult record {
    string system_target;
};

# Função responsável pela consulta no banco de dados para a obtenção do sistema alvo da orquestração.
# 
# + SOMRequest - JSON com os valores obtidos após a extração dos dados do XML recebido do SOM.
# + return - String com o sistema alvo do roteamento, podendo ter três possiveis valores:SIS V2, SIS VTAL, # FFONE.
public isolated function getDataFromDB(json SOMRequest) returns string|error {
    string host = "10.101.4.26";
    string username = "SOASIS";
    string password = "eky4cQ_nWPw_oaC_gAw5dUMmQ";
    string dbName = "sisafixa";
    string port = "1550";

    log:printInfo("Definindo o sistema alvo");
    string requestId = check SOMRequest.correlationId;
    string operation = <string> check SOMRequest.operation;
    json parameters = check SOMRequest.parameters;
    string lineId1 = parameters.LINEID1.value is error? "" : check parameters.LINEID1.value;
    string uf = "";
    if lineId1 != ""{
        uf = regex:split(lineId1, "-")[0];
    } 
    string tecnology = parameters.fornecedorCPE.value is error? "" : check parameters.fornecedorCPE.value;
    
    oracledb:Client dbClient = check new (host, username, password, dbName, check int:fromString(port));
    stream<QueryResult, sql:Error?> resultStream = dbClient->query(`SELECT system_target from soasis.system_segmentation where operation = ${operation} AND (tecnology = ${tecnology} AND uf = ${uf})`);
    string env = "";
    check from QueryResult result in resultStream
        do {
            env = result.system_target;
        };
    check resultStream.close();
    if env != "" {
        log:printInfo("Ambiente encontrado - " + env, id = requestId);
        check dbClient.close();
        return env;
    }

    log:printError("Nenhum ambiente foi encontrado com os dados fornecidos. Procurando pelo ambiente padrão para a operação " + operation, id = requestId);
    string operationEnv = ""; 
    stream<QueryResult, sql:Error?> resultStreamOperationDef = dbClient->query(`SELECT system_target from soasis.system_segmentation where operation = ${operation} AND (tecnology = '*' AND uf = '*')`);
    check from QueryResult resultOperationDef in resultStreamOperationDef
        do {
            operationEnv = resultOperationDef.system_target;
        };
    
    check resultStreamOperationDef.close();
    if operationEnv != "" {
        log:printInfo("Ambiente padrão para a operação encontrado - " + operationEnv, id = requestId);
        check dbClient.close();
        return operationEnv;
    }

    log:printError("Ambiente padrão não encontrado para a operação " + operation + ". Procurando o ambiente default", id = requestId);
    string defaultEnv = "";
    stream<QueryResult, sql:Error?> resultStreamDefault = dbClient->query(`SELECT system_target from soasis.system_segmentation where operation = 'default'`);
    check from QueryResult resultDefault in resultStreamDefault
        do{
            defaultEnv = resultDefault.system_target;
        };
    //Failsafe
    if defaultEnv == "" {
        defaultEnv = "SIS V2";
    }

    check resultStreamDefault.close();
    check dbClient.close();
    return defaultEnv;
}



# Função responsável pela realização da orquestração das chamadas.
#
# + SOMRequest - Request XML recebido do SOM.
# + return - Response XML ou JSON recebido após a orquestração.
public isolated function requestOrchestration(xml SOMRequest) returns json|xml|error{
    json|error requestTransformado = SOM:getDataFromSOMXml(SOMRequest);
    if requestTransformado is error{
        log:printError("Erro ao extrair os dados da requisição do SOM");
        return {"status": "error", "reason":"Erro ao transformar a requisição do SOM" };
    }
    string|error sistemaAlvo = getDataFromDB(requestTransformado);
    if sistemaAlvo is error{
        log:printError("Erro ao fazer a query no banco.");
        return sistemaAlvo;
    }
    if sistemaAlvo.toLowerAscii() == "ffone"{
        json|error requestFFOne = FFOne:transformRequestFFOne(requestTransformado);
        if requestFFOne is error{
            log:printError("Erro ao realizar a transformação do request para o FFOne");
            return requestFFOne;
        }
        json|error responseFFOne = FFOne:sendRequestFFOne( requestFFOne);
        if responseFFOne is error{
            log:printError("Erro ao realizar a chamada ao FFOne", responseFFOne);
            return responseFFOne;
        }
    }
    else if sistemaAlvo.toLowerAscii() == "sis vtal"{
        json|error requestSISVTal = SIS:transformRequestSISVTal(requestTransformado);
        if requestSISVTal is error{
             log:printError("Erro ao realizar a transformação do request para o SISVTal");
            return requestSISVTal;
        }
        json|error responseSISVTal = SIS:sendRequestSISVTal(requestSISVTal);
        if responseSISVTal is error{
             log:printError("Erro ao realizar a requisição para o SISVTal", responseSISVTal);
            return responseSISVTal;
        }
    }
    else if sistemaAlvo.toLowerAscii() == "sis v2"{
        xml|error responseSISV2 = SIS:sendRequestSISV2(SOMRequest);
        return responseSISV2;
    }
}


